output "environment" {
  description = "Deployed environment"
  value       = var.environment
}

output "model_name" {
  description = "Juju model name"
  value       = var.model_name
}

output "all_dns_records" {
  description = "All DNS records defined"
  value       = module.dns_records.records
}

output "all_firewall_rules" {
  description = "All firewall rules defined"
  value       = module.firewall.rules
}
