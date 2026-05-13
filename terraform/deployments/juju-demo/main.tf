# Main deployment combining all Juju-based modules
# Imitates ps7 staging architecture without real Vault/AppRole

locals {
  bare_model = "hackathon-infra-interactions-ps7-staging"
  k8s_model  = "k8s-hackathon-ps7-staging"
  cloud      = "ps7"
}

# DNS records
module "dns_records" {
  source = "../../modules/dns-records"
}

# Firewall rules
module "firewall" {
  source = "../../modules/firewall-rules"
}

# ────────────────────────────────────────────────────────────────
# 1) Bare VM model
# ────────────────────────────────────────────────────────────────

data "juju_model" "bare_model" {
  name = local.bare_model
}

module "haproxy" {
  source = "../../modules/juju-haproxy"

  model_name        = local.bare_model
  external_hostname = "ingress-ps7.demo.local"
}

module "compute" {
  source = "../../modules/juju-compute"

  model_name = local.bare_model
}

module "falcosidekick" {
  source = "../../modules/juju-falcosidekick"

  model_name       = local.bare_model
  loki_offer_url   = "admin/${local.k8s_model}.loki"
  haproxy_app_name = module.haproxy.application_name
}

module "grafana_agent" {
  source = "../../modules/juju-grafana-agent"

  model_name = local.bare_model
  target_apps = [
    module.haproxy.application_name,
    module.falcosidekick.application_name,
    module.compute.application_name,
  ]
}

module "squid" {
  source = "../../modules/juju-squid"

  model_name = local.bare_model
}

# ────────────────────────────────────────────────────────────────
# 2) K8s + COS-lite model
# ────────────────────────────────────────────────────────────────

module "k8s_cluster" {
  source = "../../modules/juju-k8s-cluster"

  model_name = local.k8s_model
  cloud      = local.cloud
}

module "cos" {
  source = "../../modules/juju-cos"

  model_uuid        = module.k8s_cluster.model_uuid
  external_hostname = "cos-lite-ps7.demo.local"
  haproxy_offer_url = juju_offer.haproxy_ingress.url
}

# ────────────────────────────────────────────────────────────────
# 3) Cross-model offers & integrations
# ────────────────────────────────────────────────────────────────

resource "juju_offer" "haproxy_ingress" {
  model            = local.bare_model
  application_name = module.haproxy.application_name
  endpoint         = "haproxy-route"

  name = "haproxy-ingress"
}

resource "juju_integration" "falcosidekick_to_loki" {
  model_uuid = module.k8s_cluster.model_uuid

  application {
    name     = module.falcosidekick.application_name
    endpoint = "logging"
  }

  application {
    offer_url = "admin/${local.k8s_model}.loki"
  }
}

resource "juju_integration" "grafana_agent_to_cos" {
  model_uuid = module.k8s_cluster.model_uuid

  application {
    name     = module.grafana_agent.application_name
    endpoint = "send-remote-write"
  }

  application {
    offer_url = "admin/${local.k8s_model}.prometheus"
  }
}

resource "juju_integration" "grafana_agent_squid" {
  model_uuid = data.juju_model.bare_model.uuid

  application {
    name     = module.grafana_agent.application_name
    endpoint = "juju-info"
  }

  application {
    name     = module.squid.application_name
    endpoint = "juju-info"
  }
}

# ────────────────────────────────────────────────────────────────
# Outputs
# ────────────────────────────────────────────────────────────────

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

output "k8s_cluster" {
  value = module.k8s_cluster
}

output "squid_app" {
  value = module.squid.application_name
}
