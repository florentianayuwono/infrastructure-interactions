output "vm_names" {
  description = "Names of created LXD VMs"
  value       = [for vm in module.vms : vm.name]
}

output "vm_ips" {
  description = "IP addresses of created LXD VMs"
  value       = { for name, vm in module.vms : name => vm.ipv4_address }
}

output "network_name" {
  description = "LXD network used for demo"
  value       = lxd_network.demo_net.name
}

output "network_cidr" {
  description = "CIDR of demo network"
  value       = var.demo_network_cidr
}
