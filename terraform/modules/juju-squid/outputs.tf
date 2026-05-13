# terraform/modules/juju-squid/outputs.tf

output "application_name" {
  description = "Name of the squid Juju application, for use in integrations"
  value       = juju_application.squid.name
}
