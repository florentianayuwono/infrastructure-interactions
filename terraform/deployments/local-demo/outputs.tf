output "network_name" {
  description = "LXD demo network"
  value       = lxd_network.demo.name
}

output "proxy_ip" {
  description = "Proxy VM IP"
  value       = module.proxy.ipv4_address
}

output "dns_ip" {
  description = "DNS VM IP"
  value       = module.dns.ipv4_address
}

output "ingress_ip" {
  description = "Ingress VM IP"
  value       = module.ingress.ipv4_address
}

output "monitoring_ip" {
  description = "Monitoring VM IP"
  value       = module.monitoring.ipv4_address
}
