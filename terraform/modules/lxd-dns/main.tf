# lxd-dns — deploy a BIND9 DNS server inside an LXD VM

variable "name" {
  description = "VM name for the DNS server"
  type        = string
  default     = "dns-vm"
}

variable "network" {
  description = "LXD network name"
  type        = string
}

variable "ip" {
  description = "Static IP for the DNS VM"
  type        = string
  default     = ""
}

locals {
  zone_file = <<-EOT
    \$TTL    604800
    @       IN      SOA     ns1.demo.local. root.demo.local. (
                              2025051301 ; Serial
                              604800     ; Refresh
                              86400      ; Retry
                              2419200    ; Expire
                              604800 )   ; Negative Cache TTL

            IN      NS      ns1.demo.local.
    @       IN      A       10.142.65.3
    ns1     IN      A       10.142.65.3
    proxy   IN      A       10.142.65.2
    ingress IN      A       10.142.65.4
    monitoring IN   A       10.142.65.5
  EOT

  named_conf = <<-EOT
    zone "demo.local" {
        type master;
        file "/etc/bind/db.demo.local";
    };
  EOT
}

module "vm" {
  source = "../lxd-vm"

  name           = var.name
  image          = "ubuntu:24.04"
  cpu            = 1
  memory         = "512MiB"
  disk           = "5GiB"
  network        = var.network
  ip             = var.ip
  packages       = ["bind9", "bind9utils"]
  config_files   = {
    "/etc/bind/db.demo.local"      = local.zone_file
    "/etc/bind/named.conf.local"   = local.named_conf
  }
  exec_commands  = [
    "chown bind:bind /etc/bind/db.demo.local",
    "systemctl enable named",
    "systemctl restart named"
  ]
}

output "vm_name" {
  value = module.vm.name
}

output "ipv4_address" {
  value = module.vm.ipv4_address
}
