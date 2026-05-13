# Sample compute VM deployment
# Imitates infrastructure-services compute resources

variable "model_name" {
  description = "Juju model name"
  type        = string
  default     = "hackathon-infra-interactions-ps7-staging"
}

data "juju_model" "demo_model" {
  name = var.model_name
}

resource "juju_application" "sample_vm" {
  name  = "sample-compute-ps7"
  model = data.juju_model.demo_model.name

  constraints = "arch=amd64 cores=2 mem=4096M root-disk=20480M"

  charm {
    name     = "ubuntu"
    channel  = "24.04/stable"
    revision = 24
  }

  config = {
    hostname = "sample-vm-ps7"
  }

  units = 1
}

output "application_name" {
  value = juju_application.sample_vm.name
}

output "model_name" {
  value = data.juju_model.demo_model.name
}
