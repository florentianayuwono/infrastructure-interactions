# Local backend (demo only)
terraform {
  backend "local" {
    path = ".terraform/terraform-juju-demo.tfstate"
  }
}
