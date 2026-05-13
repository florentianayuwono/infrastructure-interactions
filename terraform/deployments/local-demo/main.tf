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

# Create VMs for each service
module "vms" {
  source = "../../modules/lxd-vm"

  for_each = var.vm_profiles

  name     = each.key
  image    = each.value.image
  cpu      = each.value.cpu
  memory   = each.value.memory
  disk     = each.value.disk
  network  = lxd_network.demo_net.name
  ip       = each.value.ip
  packages = each.value.packages
}

# Output VM info
output "vms" {
  description = "Created VMs"
  value       = module.vms
}

output "network" {
  description = "Demo network info"
  value       = lxd_network.demo_net
}
