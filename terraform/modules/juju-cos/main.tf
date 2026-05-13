# Juju-based COS-lite deployment
# Imitates deployments/cos/ps7/staging/main.tf

variable "model_uuid" {
  description = "Juju model UUID or name for COS-lite"
  type        = string
}

variable "external_hostname" {
  description = "External hostname for COS-lite"
  type        = string
  default     = "cos-lite-ps7.demo.local"
}

variable "haproxy_offer_url" {
  description = "HAProxy offer URL for ingress"
  type        = string
  default     = "admin/hackathon-infra-interactions-ps7-staging.haproxy"
}

locals {
  model_uuid        = var.model_uuid
  external_hostname = var.external_hostname
  haproxy_offer_url = var.haproxy_offer_url
}

data "juju_model" "cos_model" {
  name = local.model_uuid
}

module "cos-lite" {
  source = "git::https://github.com/canonical/platform-engineering-deployment-modules//deployments/cos-lite/ps7?ref=main&depth=1"

  model_uuid        = data.juju_model.cos_model.uuid
  external_hostname = local.external_hostname
}

resource "juju_integration" "haproxy_ingress_alertmanager" {
  model_uuid = local.model_uuid

  application {
    offer_url = local.haproxy_offer_url
  }

  application {
    name     = module.cos-lite.components.ingress_configurator_alertmanager
    endpoint = "haproxy-route"
  }
}

resource "juju_integration" "haproxy_ingress_catalogue" {
  model_uuid = local.model_uuid

  application {
    offer_url = local.haproxy_offer_url
  }

  application {
    name     = module.cos-lite.components.ingress_configurator_catalogue
    endpoint = "haproxy-route"
  }
}

resource "juju_integration" "haproxy_ingress_grafana" {
  model_uuid = local.model_uuid

  application {
    offer_url = local.haproxy_offer_url
  }

  application {
    name     = module.cos-lite.components.ingress_configurator_grafana
    endpoint = "haproxy-route"
  }
}

resource "juju_integration" "haproxy_ingress_loki" {
  model_uuid = local.model_uuid

  application {
    offer_url = local.haproxy_offer_url
  }

  application {
    name     = module.cos-lite.components.ingress_configurator_loki
    endpoint = "haproxy-route"
  }
}

resource "juju_integration" "haproxy_ingress_prometheus" {
  model_uuid = local.model_uuid

  application {
    offer_url = local.haproxy_offer_url
  }

  application {
    name     = module.cos-lite.components.ingress_configurator_prometheus
    endpoint = "haproxy-route"
  }
}

output "ingress_configurator_alertmanager" {
  value = module.cos-lite.components.ingress_configurator_alertmanager
}

output "ingress_configurator_catalogue" {
  value = module.cos-lite.components.ingress_configurator_catalogue
}

output "ingress_configurator_grafana" {
  value = module.cos-lite.components.ingress_configurator_grafana
}

output "ingress_configurator_loki" {
  value = module.cos-lite.components.ingress_configurator_loki
}

output "ingress_configurator_prometheus" {
  value = module.cos-lite.components.ingress_configurator_prometheus
}
