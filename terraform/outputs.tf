output "instances" {
  value = zipmap(formatlist("%s.%s", scaleway_instance_server.srv.*.name, scaleway_vpc_private_network.pn.name), scaleway_vpc_public_gateway_dhcp_reservation.srv.*.ip_address)
}

output "bastion" {
  value = format("-J bastion@%s:61000", resource.scaleway_vpc_public_gateway_ip.gw_ip.address)
}

output "loadbalancer" {
  value = scaleway_lb_ip.lb_ip.ip_address
}


