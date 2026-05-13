# lxd-monitoring — deploy a COS-lite / monitoring stack inside an LXD VM

variable "name" {
  description = "VM name for monitoring"
  type        = string
  default     = "monitoring"
}

variable "network" {
  description = "LXD network name"
  type        = string
}

variable "ip" {
  description = "Static IP for the monitoring VM"
  type        = string
  default     = ""
}

variable "juju_model_name" {
  description = "Juju model name for COS-lite bootstrap"
  type        = string
  default     = "hackathon-infra-interactions-ps7-staging"
}

locals {
  cloud_init = <<-EOT
    #cloud-config
    packages:
      - snapd
      - docker.io
    runcmd:
      - systemctl enable snapd
      - snap install --classic juju || true
      - systemctl enable docker
      - systemctl start docker
  EOT
}

module "vm" {
  source = "../lxd-vm"

  name           = var.name
  image          = "ubuntu:24.04"
  cpu            = 2
  memory         = "4GiB"
  disk           = "20GiB"
  network        = var.network
  ip             = var.ip
  config_files   = {
    "/var/lib/cloud/seed/nocloud-net/user-data" = local.cloud_init
  }
  exec_commands  = [
    "cloud-init status --wait || true",
    "systemctl enable snapd || true",
    "snap install --classic juju || true"
  ]
}

output "vm_name" {
  value = module.vm.name
}

output "ipv4_address" {
  value = module.vm.ipv4_address
}
