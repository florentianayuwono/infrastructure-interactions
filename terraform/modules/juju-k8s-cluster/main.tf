# Juju-based K8s cluster deployment
# Imitates k8s-cos-ps7 pattern

locals {
  model_name = var.model_name
  cloud      = var.cloud
}

# K8s model (created externally, referenced here)
data "juju_model" "k8s_model" {
  name = local.model_name
}

# Canonical K8s charm
resource "juju_application" "canonical_k8s" {
  name  = "k8s"
  model = data.juju_model.k8s_model.name

  charm {
    name     = "canonical-k8s"
    channel  = "1.32/stable"
    revision = 1300
  }

  config = {
    "pod-cidr"     = "10.85.0.0/16"
    "service-cidr" = "10.86.0.0/16"
  }

  units = 3
}

# K8s worker charm
resource "juju_application" "k8s_worker" {
  name  = "k8s-worker"
  model = data.juju_model.k8s_model.name

  charm {
    name     = "k8s-worker"
    channel  = "1.32/stable"
    revision = 1294
  }

  config = {
    "containerd-custom-config" = ""
  }

  units = 3
}

# Integration: k8s -> k8s-worker
resource "juju_integration" "k8s_cluster" {
  model_uuid = data.juju_model.k8s_model.uuid

  application {
    name     = juju_application.canonical_k8s.name
    endpoint = "cluster"
  }

  application {
    name     = juju_application.k8s_worker.name
    endpoint = "cluster"
  }
}

# Offer the k8s relation so COS-lite (or others) can consume it
resource "juju_offer" "k8s_cluster" {
  model            = data.juju_model.k8s_model.name
  application_name = juju_application.canonical_k8s.name
  endpoint         = "cluster"

  name = "canonical-k8s"
}

output "model_uuid" {
  value = data.juju_model.k8s_model.uuid
}

output "k8s_app_name" {
  value = juju_application.canonical_k8s.name
}

output "k8s_offer_url" {
  value = juju_offer.k8s_cluster.url
}

variable "model_name" {
  description = "Juju K8s model name"
  type        = string
  default     = "k8s-hackathon-ps7-staging"
}

variable "cloud" {
  description = "OpenStack cloud name"
  type        = string
  default     = "ps7"
}
