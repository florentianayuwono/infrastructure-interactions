# Reusable LXD VM module

terraform {
  required_providers {
    lxd = {
      source  = "terraform-lxd/lxd"
      version = "~> 2.0"
    }
  }
}

variable "name" {
  description = "Name of the LXD container/VM"
  type        = string
}

variable "image" {
  description = "LXD image to use"
  type        = string
  default     = "ubuntu:24.04"
}

variable "cpu" {
  description = "Number of CPU cores"
  type        = number
  default     = 1
}

variable "memory" {
  description = "Memory limit (e.g., 2GiB)"
  type        = string
  default     = "1GiB"
}

variable "disk" {
  description = "Disk size (e.g., 10GiB)"
  type        = string
  default     = "5GiB"
}

variable "network" {
  description = "LXD network to attach"
  type        = string
}

variable "ip" {
  description = "Static IP address"
  type        = string
  default     = ""
}

variable "packages" {
  description = "Packages to install"
  type        = list(string)
  default     = []
}

variable "cloud_init_path" {
  description = "Path to cloud-init user-data file to push into VM"
  type        = string
  default     = ""
}

variable "exec_commands" {
  description = "List of shell commands to run inside the VM after creation"
  type        = list(string)
  default     = []
}

variable "config_files" {
  description = "Map of target paths => file contents to push into the VM"
  type        = map(string)
  default     = {}
}

locals {
  cloud_init_parts = {
    package_update = true
    packages       = var.packages
    write_files = [
      for path, content in var.config_files : {
        path    = path
        content = content
      }
    ]
    runcmd = var.exec_commands
  }

  cloud_init = "#cloud-config\n${yamlencode(local.cloud_init_parts)}"
}

resource "lxd_instance" "vm" {
  name  = var.name
  image = var.image
  type  = "virtual-machine"

  limits = {
    cpu    = var.cpu
    memory = var.memory
  }

  config = {
    "user.user-data" = local.cloud_init
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      pool = "default"
      path = "/"
      size = var.disk
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network        = var.network
      "ipv4.address" = var.ip != "" ? var.ip : null
    }
  }
}

output "name" {
  value = lxd_instance.vm.name
}

output "ipv4_address" {
  value = lxd_instance.vm.ipv4_address
}

output "status" {
  value = lxd_instance.vm.status
}
