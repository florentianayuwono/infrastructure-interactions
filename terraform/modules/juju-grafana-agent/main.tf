# Juju-based grafana-agent deployment for metrics collection
# Deploys across both models to collect metrics from all apps

locals {
  bare_model_name = var.bare_model_name
  k8s_model_name  = var.k8s_model_name
}

data "juju_model" "bare_model" {
  name = local.bare_model_name
}

data "juju_model" "k8s_model" {
  name = local.k8s_model_name
}

# Grafana-agent on bare metal model
resource "juju_application" "grafana_agent_bare" {
  name  = "grafana-agent"
  model = data.juju_model.bare_model.name

  charm {
    name     = "grafana-agent"
    channel  = "latest/stable"
    revision = 5
  }

  units = 0 # subordinate, auto-deploys with principal apps
}

# Integration: grafana-agent -> haproxy (metrics)
resource "juju_integration" "agent_haproxy" {
  model_uuid = data.juju_model.bare_model.uuid

  application {
    name     = juju_application.grafana_agent_bare.name
    endpoint = "grafana-agent-peers"
  }

  application {
    name     = "haproxy"
    endpoint = "grafana-dashboard"
  }
}

output "bare_model_agent" {
  value = juju_application.grafana_agent_bare.name
}

output "application_name" {
  value = juju_application.grafana_agent_bare.name
}

variable "bare_model_name" {
  description = "Bare metal Juju model"
  type        = string
  default     = "hackathon-infra-interactions-ps7-staging"
}

variable "k8s_model_name" {
  description = "K8s Juju model"
  type        = string
  default     = "k8s-hackathon-ps7-staging"
}
