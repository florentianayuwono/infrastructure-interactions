variable "name" {
  description = "Proxy instance name"
  type        = string
  default     = "proxy"
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
  default     = "10.150.0.2"
}

variable "squid_config_path" {
  description = "Path to squid.conf"
  type        = string
  default     = "../../../proxy/squid.conf"
}
