# Juju-based falcosidekick deployment
# Imitates deployments/falcosidekick/ps7/staging/main.tf

locals {
  model_name = var.model_name
}

data "juju_model" "demo_model" {
  name = local.model_name
}

# Falcosidekick charm for security event forwarding
resource "juju_application" "falcosidekick" {
  name  = "falcosidekick"
  model = data.juju_model.demo_model.name

  charm {
    name     = "falcosidekick"
    channel  = "latest/stable"
    revision = 10
  }

  config = {
    "webui" = "true"
  }

  units = 1
}

# Integration: falcosidekick -> loki (log forwarding)
resource "juju_integration" "falcosidekick_loki" {
  model_uuid = data.juju_model.demo_model.uuid

  application {
    name     = juju_application.falcosidekick.name
    endpoint = "logging"
  }

  application {
    offer_url = var.loki_offer_url
  }
}

# Integration: falcosidekick -> haproxy (juju-info endpoint)
resource "juju_integration" "falcosidekick_haproxy" {
  model_uuid = data.juju_model.demo_model.uuid

  application {
    name     = juju_application.falcosidekick.name
    endpoint = "juju-info"
  }

  application {
    offer_url = var.haproxy_offer_url
  }
}

output "application_name" {
  value = juju_application.falcosidekick.name
}

variable "model_name" {
  description = "Juju model name"
  type        = string
  default     = "hackathon-infra-interactions-ps7-staging"
}

variable "loki_offer_url" {
  description = "Loki offer URL for log forwarding"
  type        = string
  default     = "admin/k8s-hackathon-ps7-staging.loki"
}

variable "haproxy_offer_url" {
  description = "HAProxy offer URL for juju-info"
  type        = string
  default     = "admin/hackathon-infra-interactions-ps7-staging.haproxy"
}
