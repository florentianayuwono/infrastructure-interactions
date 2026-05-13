# Juju-based haproxy deployment
# Imitates deployments/haproxy/ps7/staging/main.tf

variable "model_name" {
  description = "Juju model name"
  type        = string
  default     = "hackathon-infra-interactions-ps7-staging"
}

variable "external_hostname" {
  description = "External hostname"
  type        = string
  default     = "ingress-ps7.demo.local"
}

locals {
  model_name        = var.model_name
  external_hostname = var.external_hostname
}

data "juju_model" "demo_model" {
  name = local.model_name
}

module "haproxy" {
  source     = "git::https://github.com/canonical/haproxy-operator//terraform/product?ref=main&depth=1"
  model_uuid = data.juju_model.demo_model.uuid
  haproxy = {
    revision = 315
    units    = 1
  }

  haproxy_ddos_protection_configurator = {
    config = {
      rate-limit-requests-per-minute    = 55
      rate-limit-connections-per-minute = 50
      limit-policy-http                 = "deny 503"
      limit-policy-tcp                  = "reject"
      http-request-timeout              = 50
      client-timeout                    = 30
    }
  }

  keepalived = {
    config = {
      virtual_ip = "10.142.65.4"
    }
  }
}

module "ingress_configurator" {
  source     = "git::https://github.com/canonical/ingress-configurator-operator//terraform?ref=main&depth=1"
  model_uuid = data.juju_model.demo_model.uuid
  config     = {}
}

resource "juju_integration" "haproxy_ingress_configurator" {
  model_uuid = data.juju_model.demo_model.uuid

  application {
    name     = module.ingress_configurator.app_name
    endpoint = module.ingress_configurator.endpoints.haproxy_route
  }

  application {
    name     = module.haproxy.app_name
    endpoint = module.haproxy.endpoints.haproxy_route
  }
}

output "application_name" {
  value = module.haproxy.app_name
}
