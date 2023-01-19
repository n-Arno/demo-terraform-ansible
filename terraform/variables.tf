variable "scale" {
  default = 3
}

variable "private_cidr" {
  default = { network = "192.168.0", subnet = "/24" }
}
