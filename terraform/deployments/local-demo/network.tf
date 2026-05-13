resource "lxd_network" "demo" {
  name = var.network_name

  config = {
    "ipv4.address" = var.subnet
    "ipv4.nat"     = "true"
    "ipv4.dhcp"    = "true"
    "ipv4.dhcp.ranges" = "10.150.0.100-10.150.0.200"
    "dns.domain"   = "demo.local"
    "dns.mode"     = "managed"
  }
}
