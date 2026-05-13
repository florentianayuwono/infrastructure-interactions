# Reusable LXD VM module

variable "name" {
  description = "Name of the LXD container/VM"
  type        = string
}

variable "image" {
  description = "LXD image to use"
  type        = string
  default     = "ubuntu:24.04"
}

variable "cpu" {
  description = "Number of CPU cores"
  type        = number
  default     = 1
}

variable "memory" {
  description = "Memory limit (e.g., 2GiB)"
  type        = string
  default     = "1GiB"
}

variable "disk" {
  description = "Disk size (e.g., 10GiB)"
  type        = string
  default     = "5GiB"
}

variable "network" {
  description = "LXD network to attach"
  type        = string
}

variable "ip" {
  description = "Static IP address"
  type        = string
  default     = ""
}

variable "packages" {
  description = "Packages to install"
  type        = list(string)
  default     = []
}

variable "cloud_init_path" {
  description = "Path to cloud-init user-data file to push into VM"
  type        = string
  default     = ""
}

variable "exec_commands" {
  description = "List of shell commands to run inside the VM after creation"
  type        = list(string)
  default     = []
}

variable "config_files" {
  description = "Map of target paths => file contents to push into the VM"
  type        = map(string)
  default     = {}
}

resource "lxd_instance" "vm" {
  name  = var.name
  image = var.image
  type  = "virtual-machine"

  limits = {
    cpu    = var.cpu
    memory = var.memory
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      pool = "default"
      path = "/"
      size = var.disk
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network        = var.network
      "ipv4.address" = var.ip != "" ? var.ip : null
    }
  }
}

# Push config files into the VM
resource "lxd_file" "configs" {
  for_each = var.config_files

  remote      = "local"
  instance    = lxd_instance.vm.name
  target_path = each.key
  content     = each.value
}

# Execute provisioning commands inside the VM
resource "lxd_exec" "provision" {
  count = length(var.exec_commands) > 0 ? 1 : 0

  remote   = "local"
  instance = lxd_instance.vm.name

  command = join(" && ", var.exec_commands)
}

output "name" {
  value = lxd_instance.vm.name
}

output "ipv4_address" {
  value = lxd_instance.vm.ipv4_address
}

output "status" {
  value = lxd_instance.vm.status
}
