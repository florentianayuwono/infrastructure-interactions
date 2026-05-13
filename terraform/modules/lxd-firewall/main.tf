# lxd-firewall — deploy UFW firewall rules inside an LXD VM

variable "name" {
  description = "VM name for the firewall"
  type        = string
  default     = "firewall-vm"
}

variable "network" {
  description = "LXD network name"
  type        = string
}

variable "ip" {
  description = "Static IP for the firewall VM"
  type        = string
  default     = ""
}

variable "allowed_ports" {
  description = "List of ports to allow through UFW"
  type        = list(string)
  default     = ["22/tcp", "80/tcp", "443/tcp", "3128/tcp", "53/tcp", "53/udp"]
}

variable "allowed_subnets" {
  description = "List of CIDRs to allow"
  type        = list(string)
  default     = ["10.142.65.0/24"]
}

locals {
  ufw_rules = join("\n", concat(
    ["ufw --force reset", "ufw default deny incoming", "ufw default allow outgoing"],
    [for port in var.allowed_ports : "ufw allow ${port}"],
    [for subnet in var.allowed_subnets : "ufw allow from ${subnet}"],
    ["ufw --force enable"]
  ))
}

module "vm" {
  source = "../lxd-vm"

  name           = var.name
  image          = "ubuntu:24.04"
  cpu            = 1
  memory         = "512MiB"
  disk           = "5GiB"
  network        = var.network
  ip             = var.ip
  packages       = ["ufw"]
  exec_commands  = [local.ufw_rules]
}

output "vm_name" {
  value = module.vm.name
}

output "ipv4_address" {
  value = module.vm.ipv4_address
}
