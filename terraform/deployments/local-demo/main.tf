# Main deployment for local demo infrastructure
# Imitates ps7 OpenStack environment on LXD VMs

# Create demo network
resource "lxd_network" "demo_net" {
  name = var.demo_network_name

  config = {
    "ipv4.address" = var.demo_network_cidr
    "ipv4.nat"     = "true"
    "ipv6.address" = "none"
  }
}

# Deploy proxy VM with Squid
module "proxy" {
  source = "../../modules/lxd-proxy"

  name    = "squid-proxy"
  network = lxd_network.demo_net.name
  ip      = "10.142.65.2"
}

# Deploy DNS VM with BIND9
module "dns" {
  source = "../../modules/lxd-dns"

  name    = "dns-server"
  network = lxd_network.demo_net.name
  ip      = "10.142.65.3"
}

# Deploy ingress VM with HAProxy
module "ingress" {
  source = "../../modules/lxd-ingress"

  name    = "ingress-controller"
  network = lxd_network.demo_net.name
  ip      = "10.142.65.4"
}

# Deploy monitoring VM (COS-lite ready)
module "monitoring" {
  source = "../../modules/lxd-monitoring"

  name    = "monitoring"
  network = lxd_network.demo_net.name
  ip      = "10.142.65.5"
}

# Deploy firewall VM with UFW rules
module "firewall" {
  source = "../../modules/lxd-firewall"

  name            = "firewall"
  network         = lxd_network.demo_net.name
  ip              = "10.142.65.6"
  allowed_ports   = ["22/tcp", "80/tcp", "443/tcp", "3128/tcp", "53/tcp", "53/udp"]
  allowed_subnets = [var.demo_network_cidr]
}
