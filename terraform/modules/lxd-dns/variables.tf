variable "name" {
  description = "DNS instance name"
  type        = string
  default     = "dns"
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
  default     = "512MiB"
}

variable "disk_size" {
  description = "Disk size"
  type        = string
  default     = "5GiB"
}

variable "network" {
  description = "LXD network"
  type        = string
}

variable "ipv4_address" {
  description = "Static IPv4"
  type        = string
  default     = "10.150.0.3"
}

variable "zone_file_path" {
  description = "Path to zone file"
  type        = string
  default     = "../../../dns/db.demo.local"
}

variable "named_conf_path" {
  description = "Path to named.conf.local"
  type        = string
  default     = "../../../dns/named.conf.local"
}
