# Main deployment combining all Juju-based modules
# Imitates ps7 staging architecture without real Vault/AppRole

locals {
  model_name = "hackathon-infra-interactions-ps7-staging"
}

# DNS records
module "dns_records" {
  source = "../modules/dns-records"
}

# Firewall rules
module "firewall" {
  source = "../modules/firewall-rules"
}

# HAProxy ingress
module "haproxy" {
  source = "../modules/juju-haproxy"
}

# COS-lite monitoring
module "cos" {
  source = "../modules/juju-cos"
}

# Sample compute VM
module "compute" {
  source = "../modules/juju-compute"
}

# Outputs
output "dns_zone" {
  value = module.dns_records.zone
}

output "dns_records" {
  value = module.dns_records.records
}

output "firewall_rules" {
  value = module.firewall.rules
}

output "haproxy_model" {
  value = module.haproxy
}

output "cos_model" {
  value = module.cos
}

output "compute_app" {
  value = module.compute.application_name
}
