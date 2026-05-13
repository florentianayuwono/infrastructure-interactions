terraform {
  required_providers {
    lxd = {
      source  = "terraform-lxd/lxd"
      version = "~> 2.5.0"
    }
  }
}

resource "lxd_network_acl" "demo_acl" {
  name = var.acl_name

  egress {
    action           = "allow"
    state            = "enabled"
    description      = "Allow all outbound"
    destination      = ""
    destination_port = ""
    protocol         = ""
    source           = ""
    source_port      = ""
  }

  ingress {
    action           = "allow"
    state            = "enabled"
    description      = "Allow SSH"
    destination      = ""
    destination_port = "22"
    protocol         = "tcp"
    source           = ""
    source_port      = ""
  }

  ingress {
    action           = "allow"
    state            = "enabled"
    description      = "Allow HTTP"
    destination_port = "80"
    protocol         = "tcp"
  }

  ingress {
    action           = "allow"
    state            = "enabled"
    description      = "Allow HTTPS"
    destination_port = "443"
    protocol         = "tcp"
  }

  ingress {
    action           = "allow"
    state            = "enabled"
    description      = "Allow Squid proxy"
    destination_port = "3128"
    protocol         = "tcp"
  }

  ingress {
    action           = "allow"
    state            = "enabled"
    description      = "Allow DNS TCP"
    destination_port = "53"
    protocol         = "tcp"
  }

  ingress {
    action           = "allow"
    state            = "enabled"
    description      = "Allow DNS UDP"
    destination_port = "53"
    protocol         = "udp"
  }

  ingress {
    action           = "allow"
    state            = "enabled"
    description      = "Allow intra-subnet"
    source           = "10.150.0.0/24"
  }

  ingress {
    action           = "allow"
    state            = "enabled"
    description      = "Allow ICMP"
    protocol         = "icmp"
  }

  ingress {
    action           = "drop"
    state            = "enabled"
    description      = "Deny all other inbound"
  }
}
