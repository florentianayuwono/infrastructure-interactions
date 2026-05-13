variable "name" {
  description = "Ingress instance name"
  type        = string
  default     = "ingress"
}

variable "image" {
  description = "LXD image"
  type        = string
  default     = "ubuntu:24.04"
}

variable "type" {
  description = "Instance type"
  type        = string
  default     = "container"
}

variable "cpu" {
  description = "CPU limit"
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory limit"
  type        = string
  default     = "1GiB"
}

variable "disk_size" {
  description = "Disk size"
  type        = string
  default     = "10GiB"
}

variable "network" {
  description = "LXD network"
  type        = string
}

variable "ipv4_address" {
  description = "Static IPv4"
  type        = string
  default     = "10.150.0.4"
}

variable "haproxy_config_path" {
  description = "Path to haproxy.cfg"
  type        = string
  default     = "../../../ingress/haproxy.cfg"
}
