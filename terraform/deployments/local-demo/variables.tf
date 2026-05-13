variable "demo_network_name" {
  description = "Name of the LXD network for demo"
  type        = string
  default     = "demo-net"
}

variable "demo_network_cidr" {
  description = "CIDR for demo network"
  type        = string
  default     = "10.142.65.0/24"
}

variable "vm_profiles" {
  description = "Map of VM names to their configurations"
  type = map(object({
    image    = string
    cpu      = number
    memory   = string
    disk     = string
    ip       = string
    packages = list(string)
  }))
  default = {
    squid-proxy = {
      image    = "ubuntu:24.04"
      cpu      = 2
      memory   = "2GiB"
      disk     = "10GiB"
      ip       = "10.142.65.2"
      packages = ["squid"]
    }
    dns-server = {
      image    = "ubuntu:24.04"
      cpu      = 1
      memory   = "1GiB"
      disk     = "5GiB"
      ip       = "10.142.65.3"
      packages = ["bind9"]
    }
    ingress-controller = {
      image    = "ubuntu:24.04"
      cpu      = 2
      memory   = "2GiB"
      disk     = "10GiB"
      ip       = "10.142.65.4"
      packages = ["haproxy"]
    }
    monitoring = {
      image    = "ubuntu:24.04"
      cpu      = 2
      memory   = "4GiB"
      disk     = "20GiB"
      ip       = "10.142.65.5"
      packages = []
    }
  }
}
