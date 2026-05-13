# K8s Demo Deployment
# Imitates k8s-cos-ps7 pattern from infrastructure-services

locals {
  k8s_model_name = "k8s-hackathon-ps7-staging"
}

data "juju_model" "k8s_model" {
  name = local.k8s_model_name
}

# MicroK8s or Charmed Kubernetes
resource "juju_application" "kubernetes" {
  name  = "k8s-cluster-ps7"
  model = data.juju_model.k8s_model.name

  charm {
    name     = "kubernetes-control-plane"
    channel  = "1.28/stable"
    revision = 100
  }

  config = {
    service-cidr = "10.152.183.0/24"
  }

  units = 1
}

# Containerd
resource "juju_application" "containerd" {
  name  = "containerd"
  model = data.juju_model.k8s_model.name

  charm {
    name     = "containerd"
    channel  = "stable"
    revision = 75
  }
}

# Integrate containerd with kubernetes
resource "juju_integration" "k8s_containerd" {
  model = data.juju_model.k8s_model.name

  application {
    name     = juju_application.kubernetes.name
    endpoint = "containerd"
  }

  application {
    name     = juju_application.containerd.name
    endpoint = "containerd"
  }
}

# COS Lite on K8s
module "cos-lite-k8s" {
  source = "git::https://github.com/canonical/platform-engineering-deployment-modules//deployments/cos-lite/ps7?ref=main&depth=1"

  model_uuid        = data.juju_model.k8s_model.uuid
  external_hostname = "cos-lite-k8s-ps7.demo.local"
}

output "k8s_model" {
  value = data.juju_model.k8s_model.name
}

output "kubernetes_app" {
  value = juju_application.kubernetes.name
}
