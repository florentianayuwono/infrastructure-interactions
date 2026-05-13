# Juju-based COS-lite deployment
# Imitates deployments/cos/ps7/staging/main.tf

locals {
  model_uuid        = "hackathon-infra-interactions-ps7-staging"
  external_hostname = "cos-lite-ps7.demo.local"
  haproxy_offer_url = "admin/hackathon-infra-interactions-ps7-staging.pfe-default-ingress"
}

module "cos-lite" {
  source = "git::https://github.com/canonical/platform-engineering-deployment-modules//deployments/cos-lite/ps7?ref=main&depth=1"

  model_uuid        = local.model_uuid
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
