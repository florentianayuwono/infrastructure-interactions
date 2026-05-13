# Juju squid deployment targeting a local LXD controller

terraform {
  required_providers {
    juju = {
      source  = "juju/juju"
      version = "~> 0.10"
    }
  }
}

provider "juju" {}
