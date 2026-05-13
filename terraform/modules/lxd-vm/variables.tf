variable "name" {
  description = "Name of the LXD instance"
  type        = string
}

variable "image" {
  description = "LXD image to use"
  type        = string
  default     = "ubuntu:24.04"
}

variable "type" {
  description = "Instance type: container or virtual-machine"
  type        = string
  default     = "container"
}

variable "cpu" {
  description = "CPU limit"
  type        = string
  default     = "2"
}

variable "memory" {
  description = "Memory limit"
  type        = string
  default     = "4GiB"
}

variable "disk_size" {
  description = "Root disk size"
  type        = string
  default     = "20GiB"
}

variable "storage_pool" {
  description = "LXD storage pool"
  type        = string
  default     = "default"
}

variable "network" {
  description = "LXD network to attach"
  type        = string
}

variable "ipv4_address" {
  description = "Static IPv4 address"
  type        = string
}

variable "cloud_init" {
  description = "Cloud-init user-data"
  type        = string
  default     = ""
}
