terraform {
  required_providers {
    lxd = {
      source  = "terraform-lxd/lxd"
      version = "~> 2.5.0"
    }
  }
}

module "ingress_vm" {
  source = "../lxd-vm"

  name         = var.name
  image        = var.image
  type         = var.type
  cpu          = var.cpu
  memory       = var.memory
  disk_size    = var.disk_size
  network      = var.network
  ipv4_address = var.ipv4_address
  cloud_init   = templatefile("${path.module}/cloud-init.yml", {
    haproxy_cfg = file(var.haproxy_config_path)
  })
}
