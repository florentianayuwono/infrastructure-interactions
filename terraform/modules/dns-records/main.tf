# DNS record resources
# Imitates canonical-is-dns-configs patterns

locals {
  zone = "demo.local"
  records = {
    "proxy"           = { type = "A", value = "10.142.65.2" }
    "dns"             = { type = "A", value = "10.142.65.3" }
    "ingress"         = { type = "A", value = "10.142.65.4" }
    "monitoring"      = { type = "A", value = "10.142.65.5" }
    "cos-lite-ps7"    = { type = "CNAME", value = "monitoring.demo.local." }
    "falcosidekick-ps7" = { type = "CNAME", value = "monitoring.demo.local." }
    "www"             = { type = "CNAME", value = "ingress.demo.local." }
    "api"             = { type = "CNAME", value = "ingress.demo.local." }
  }
}

# Represented as local values for demo
# In real ps7, these would be managed via MAAS, BIND, or external DNS provider

output "zone" {
  value = local.zone
}

output "records" {
  value = local.records
}
