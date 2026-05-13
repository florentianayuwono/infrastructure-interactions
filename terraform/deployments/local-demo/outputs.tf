output "proxy" {
  description = "Proxy VM"
  value       = module.proxy
}

output "dns" {
  description = "DNS VM"
  value       = module.dns
}

output "ingress" {
  description = "Ingress VM"
  value       = module.ingress
}

output "monitoring" {
  description = "Monitoring VM"
  value       = module.monitoring
}

output "firewall" {
  description = "Firewall VM"
  value       = module.firewall
}

output "network" {
  description = "Demo network info"
  value       = lxd_network.demo_net
}
