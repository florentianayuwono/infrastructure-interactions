variable "network_name" {
  description = "LXD network name"
  type        = string
  default     = "lxdbr0-demo"
}

variable "subnet" {
  description = "Network subnet CIDR"
  type        = string
  default     = "10.150.0.0/24"
}

variable "vm_type" {
  description = "LXD instance type: container or virtual-machine"
  type        = string
  default     = "container"
}

variable "image" {
  description = "LXD image"
  type        = string
  default     = "ubuntu:24.04"
}
