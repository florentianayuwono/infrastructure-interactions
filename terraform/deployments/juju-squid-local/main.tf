# Juju squid egress proxy — local LXD deployment
#
# Replaces the LXD-native squid-proxy VM (10.142.65.2) from local-demo
# with a Juju-managed squid-reverseproxy charm unit on the same LXD host.
#
# Prerequisites:
#   Run scripts/bootstrap-juju-lxd.sh first to set up the controller + model.
#
# Usage:
#   terraform init
#   terraform apply
#   Run scripts/cutover-to-juju-squid.sh to cut DNS/HAProxy over to new unit.

locals {
  model = "demo-squid"
}

module "squid" {
  source = "../../modules/juju-squid"

  model_name = local.model
}

output "squid_app" {
  description = "Juju application name for the deployed squid unit"
  value       = module.squid.application_name
}
