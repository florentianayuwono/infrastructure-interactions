terraform {
  required_providers {
    lxd = {
      source  = "terraform-lxd/lxd"
      version = "~> 2.5.0"
    }
  }
}

resource "lxd_instance" "vm" {
  name      = var.name
  image     = var.image
  type      = var.type
  ephemeral = false

  limits = {
    cpu    = var.cpu
    memory = var.memory
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      pool = var.storage_pool
      path = "/"
      size = var.disk_size
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network    = var.network
      "ipv4.address" = var.ipv4_address
    }
  }

  config = {
    "user.user-data" = var.cloud_init
    "raw.lxc"        = "lxc.cgroup.devices.allow = c 10:237 rwm"
  }
}
