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
  default = {}
}
