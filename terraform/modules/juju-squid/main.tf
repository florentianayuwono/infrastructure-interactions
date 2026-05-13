# terraform/modules/juju-squid/main.tf
# Juju-based squid egress proxy deployment
# Imitates the ps7 squid.internal egress proxy
# Upstream firewall source: git+ssh://charlie4284@git.launchpad.net/canonical-is-firewalls
# Upstream proxy source:    git+ssh://charlie4284@git.launchpad.net/~charlie4284/canonical-is-internal-proxy-configs

locals {
  model_name = var.model_name
}

data "juju_model" "demo_model" {
  name = local.model_name
}

resource "juju_application" "squid" {
  name  = "squid"
  model = data.juju_model.demo_model.name

  charm {
    name     = "squid-reverseproxy"
    channel  = "latest/stable"
    revision = 24 # pinned on 2026-05-13
  }

  units = 1

  config = {
    # Port — mirrors defs/ports.yaml: squid: [tcp/3128]
    port = "3128"

    # Allowed source networks — mirrors demo/rules/demo/proxy.yaml:
    #   subnets/demo-network (10.142.0.0/16)
    #   subnets/rfc1918 (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
    # 10.142.0.0/16 (demo-network) is a subset of 10.0.0.0/8 (rfc1918);
    # included explicitly to match the policy declarations in demo/rules/demo/proxy.yaml
    allowed-networks = "10.142.0.0/16 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"

    # Safe outbound ports — mirrors upstream rules/is/squid.yaml allowed ports:
    #   ftp (21), http (80), https (443), matrix-federation (8448)
    safe-ports = "21 80 443 8448"
  }
}
