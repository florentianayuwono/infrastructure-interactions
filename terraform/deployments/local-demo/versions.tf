terraform {
  required_version = ">= 1.6.6"

  required_providers {
    lxd = {
      source  = "terraform-lxd/lxd"
      version = "~> 2.5.0"
    }
  }
}
