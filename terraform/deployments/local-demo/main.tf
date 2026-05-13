module "firewall" {
  source   = "../../modules/lxd-firewall"
  acl_name = "demo-firewall"
}

module "proxy" {
  source   = "../../modules/lxd-proxy"
  name     = "proxy"
  network  = lxd_network.demo.name
  ipv4_address = "10.150.0.2"
  type     = var.vm_type
  image    = var.image
}

module "dns" {
  source   = "../../modules/lxd-dns"
  name     = "dns"
  network  = lxd_network.demo.name
  ipv4_address = "10.150.0.3"
  type     = var.vm_type
  image    = var.image
}

module "ingress" {
  source   = "../../modules/lxd-ingress"
  name     = "ingress"
  network  = lxd_network.demo.name
  ipv4_address = "10.150.0.4"
  type     = var.vm_type
  image    = var.image
}

module "monitoring" {
  source   = "../../modules/lxd-vm"
  name     = "monitoring"
  network  = lxd_network.demo.name
  ipv4_address = "10.150.0.5"
  type     = var.vm_type
  image    = var.image
  cpu      = "2"
  memory   = "2GiB"
  disk_size = "20GiB"
}
