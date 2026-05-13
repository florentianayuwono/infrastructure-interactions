# lxd-ingress — deploy HAProxy ingress inside an LXD VM

variable "name" {
  description = "VM name for the ingress"
  type        = string
  default     = "ingress-vm"
}

variable "network" {
  description = "LXD network name"
  type        = string
}

variable "ip" {
  description = "Static IP for the ingress VM"
  type        = string
  default     = ""
}

locals {
  haproxy_cfg = <<-EOT
    global
      maxconn 4096
      log /dev/log local0

    defaults
      mode http
      timeout connect 5000ms
      timeout client 50000ms
      timeout server 50000ms

    frontend http_front
      bind *:80
      bind *:443
      stats uri /stats
      stats auth admin:admin
      use_backend proxy_backend if { hdr(host) -i proxy.demo.local }
      use_backend dns_backend    if { hdr(host) -i dns.demo.local }
      use_backend mon_backend    if { hdr(host) -i monitoring.demo.local }

    backend proxy_backend
      server proxy 10.142.65.2:3128 check

    backend dns_backend
      server dns 10.142.65.3:53 check

    backend mon_backend
      server monitoring 10.142.65.5:80 check
  EOT
}

module "vm" {
  source = "../lxd-vm"

  name           = var.name
  image          = "ubuntu:24.04"
  cpu            = 1
  memory         = "1GiB"
  disk           = "5GiB"
  network        = var.network
  ip             = var.ip
  packages       = ["haproxy", "openssl"]
  config_files   = {
    "/etc/haproxy/haproxy.cfg" = local.haproxy_cfg
  }
  exec_commands  = [
    "systemctl stop haproxy || true",
    "systemctl reset-failed haproxy || true",
    "mkdir -p /etc/ssl/certs /etc/ssl/private",
    "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/haproxy-selfsigned.key -out /etc/ssl/certs/haproxy-selfsigned.pem -subj '/CN=ingress.demo.local'",
    "cat /etc/ssl/private/haproxy-selfsigned.key >> /etc/ssl/certs/haproxy-selfsigned.pem",
    "systemctl enable haproxy",
    "systemctl restart haproxy"
  ]
}

output "vm_name" {
  value = module.vm.name
}

output "ipv4_address" {
  value = module.vm.ipv4_address
}
