output "name" {
  description = "Instance name"
  value       = lxd_instance.vm.name
}

output "ipv4_address" {
  description = "Instance IPv4 address"
  value       = lxd_instance.vm.ipv4_address
}

output "status" {
  description = "Instance status"
  value       = lxd_instance.vm.status
}
