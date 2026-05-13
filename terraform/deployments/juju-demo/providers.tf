# Juju-based demo deployment (ps7 imitation)

terraform {
  required_providers {
    juju = {
      source  = "juju/juju"
      version = "~> 0.10"
    }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "juju" {}
