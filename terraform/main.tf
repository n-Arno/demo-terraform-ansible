resource "scaleway_vpc_private_network" "pn" {
  name = "private"
}

resource "scaleway_vpc_public_gateway_ip" "gw_ip" {}

resource "scaleway_vpc_public_gateway_dhcp" "dhcp" {
  subnet               = format("%s.%d%s", var.private_cidr.network, 0, var.private_cidr.subnet)
  address              = format("%s.%d", var.private_cidr.network, 1)
  pool_low             = format("%s.%d", var.private_cidr.network, 2)
  pool_high            = format("%s.%d", var.private_cidr.network, 99)
  enable_dynamic       = true
  push_default_route   = true
  push_dns_server      = true
  dns_servers_override = [format("%s.%d", var.private_cidr.network, 1)]
  dns_local_name       = scaleway_vpc_private_network.pn.name
  depends_on           = [scaleway_vpc_private_network.pn]
}

resource "scaleway_vpc_public_gateway" "pgw" {
  name            = "gateway"
  type            = "VPC-GW-S"
  bastion_enabled = true
  ip_id           = scaleway_vpc_public_gateway_ip.gw_ip.id
  depends_on      = [scaleway_vpc_public_gateway_ip.gw_ip]
}

resource "scaleway_vpc_gateway_network" "vpc" {
  gateway_id         = scaleway_vpc_public_gateway.pgw.id
  private_network_id = scaleway_vpc_private_network.pn.id
  dhcp_id            = scaleway_vpc_public_gateway_dhcp.dhcp.id
  cleanup_dhcp       = true
  enable_masquerade  = true
  depends_on         = [scaleway_vpc_public_gateway.pgw, scaleway_vpc_private_network.pn, scaleway_vpc_public_gateway_dhcp.dhcp, scaleway_instance_server.srv]
}

resource "scaleway_instance_volume" "data" {
  count      = var.scale
  name       = format("data-%d", count.index)
  size_in_gb = 40
  type       = "b_ssd"
}


resource "scaleway_instance_server" "srv" {
  count = var.scale
  name  = format("srv-%d", count.index)
  image = "ubuntu_focal"
  type  = "DEV1-M"

  private_network {
    pn_id = scaleway_vpc_private_network.pn.id
  }

  additional_volume_ids = [scaleway_instance_volume.data[count.index].id]

  user_data = {
    cloud-init = <<-EOT
    #cloud-config
    runcmd:
      - apt-get update
      - reboot # Make sure static DHCP reservation catch up
    EOT
  }
}

resource "scaleway_vpc_public_gateway_dhcp_reservation" "srv" {
  count              = var.scale
  gateway_network_id = scaleway_vpc_gateway_network.vpc.id
  mac_address        = scaleway_instance_server.srv[count.index].private_network.0.mac_address
  ip_address         = format("%s.%d", var.private_cidr.network, (100 + count.index))
  depends_on         = [scaleway_instance_server.srv]
}

resource "scaleway_lb_ip" "lb_ip" {}

resource "scaleway_lb" "lb" {
  name  = "loadbalancer"
  ip_id = scaleway_lb_ip.lb_ip.id
  type  = "LB-S"
  private_network {
    private_network_id = scaleway_vpc_private_network.pn.id
    dhcp_config        = true
  }
}

resource "scaleway_lb_backend" "backend" {
  name             = "backend"
  lb_id            = scaleway_lb.lb.id
  forward_protocol = "tcp"
  forward_port     = 27017
  server_ips       = scaleway_vpc_public_gateway_dhcp_reservation.srv.*.ip_address

  health_check_tcp {}
}

resource "scaleway_lb_frontend" "frontend" {
  name         = "frontend"
  lb_id        = scaleway_lb.lb.id
  backend_id   = scaleway_lb_backend.backend.id
  inbound_port = 27017
}
