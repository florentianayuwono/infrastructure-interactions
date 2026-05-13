# lxd-proxy — deploy a Squid proxy inside an LXD VM

variable "name" {
  description = "VM name for the proxy"
  type        = string
  default     = "proxy-vm"
}

variable "network" {
  description = "LXD network name"
  type        = string
}

variable "ip" {
  description = "Static IP for the proxy VM"
  type        = string
  default     = ""
}

locals {
  squid_config = <<-EOT
    # Squid config for demo (imitates egress.ps7.internal:3128)
    http_port 3128
    visible_hostname squid-proxy-ps7
    cache_dir ufs /var/spool/squid 100 16 256

    acl localnet src 10.142.0.0/16
    http_access allow localnet
    http_access deny all
  EOT
}

module "vm" {
  source = "../lxd-vm"

  name           = var.name
  image          = "ubuntu:24.04"
  cpu            = 1
  memory         = "1GiB"
  disk           = "5GiB"
  network        = var.network
  ip             = var.ip
  packages       = ["squid"]
  config_files   = {
    "/etc/squid/squid.conf" = local.squid_config
  }
  exec_commands  = [
    "systemctl enable squid",
    "systemctl restart squid"
  ]
}

output "vm_name" {
  value = module.vm.name
}

output "ipv4_address" {
  value = module.vm.ipv4_address
}
