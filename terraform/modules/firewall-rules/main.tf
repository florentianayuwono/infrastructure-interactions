# Firewall rule configurations
# Imitates canonical-is-firewalls patterns

locals {
  firewall_rules = {
    ssh = {
      direction   = "ingress"
      protocol    = "tcp"
      port        = 22
      cidr_blocks = ["10.142.0.0/16"]
      description = "SSH access from demo network"
    }
    http = {
      direction   = "ingress"
      protocol    = "tcp"
      port        = 80
      cidr_blocks = ["10.142.0.0/16", "0.0.0.0/0"]
      description = "HTTP access"
    }
    https = {
      direction   = "ingress"
      protocol    = "tcp"
      port        = 443
      cidr_blocks = ["10.142.0.0/16", "0.0.0.0/0"]
      description = "HTTPS access"
    }
    proxy = {
      direction   = "ingress"
      protocol    = "tcp"
      port        = 3128
      cidr_blocks = ["10.142.0.0/16"]
      description = "Squid proxy access from demo network"
    }
    dns = {
      direction   = "ingress"
      protocol    = "udp"
      port        = 53
      cidr_blocks = ["10.142.0.0/16"]
      description = "DNS access from demo network"
    }
    inter_vm = {
      direction   = "ingress"
      protocol    = "all"
      port        = 0
      cidr_blocks = ["10.142.0.0/16"]
      description = "Inter-VM traffic within demo network"
    }
  }

  default_deny = {
    direction   = "ingress"
    protocol    = "all"
    port        = 0
    cidr_blocks = ["0.0.0.0/0"]
    description = "Deny all other inbound traffic"
  }
}

output "rules" {
  value = local.firewall_rules
}

output "default_deny" {
  value = local.default_deny
}
