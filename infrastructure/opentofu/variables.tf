variable "rocky_image_path" {
  description = "Path to the locally downloaded Rocky Linux GenericCloud QCOW2 image."
  type        = string
}

variable "rocky_image_sha256" {
  description = "Expected SHA-256 checksum of the local Rocky Linux image."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{64}$", var.rocky_image_sha256))
    error_message = "rocky_image_sha256 must be a 64-character hexadecimal SHA-256 digest."
  }
}

variable "hostonly_adapter" {
  description = "Existing VirtualBox host-only interface name."
  type        = string
  default     = "vboxnet0"
}

variable "vm_root_dir" {
  description = "Directory where this lab's VirtualBox VM files are stored."
  type        = string
  default     = "~/VirtualBox VMs/k8s-security-lab"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key installed into every VM."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "nodes" {
  description = "Kubernetes lab node definitions."
  type = map(object({
    name         = string
    cpus         = number
    memory_mb    = number
    disk_size_mb = number
    hostonly_ip  = string
  }))

  default = {
    cp01 = {
      name         = "k8s-cp01"
      cpus         = 2
      memory_mb    = 4096
      disk_size_mb = 51200
      hostonly_ip  = "192.168.56.101"
    }
    worker01 = {
      name         = "k8s-worker01"
      cpus         = 2
      memory_mb    = 4096
      disk_size_mb = 51200
      hostonly_ip  = "192.168.56.102"
    }
    worker02 = {
      name         = "k8s-worker02"
      cpus         = 2
      memory_mb    = 4096
      disk_size_mb = 51200
      hostonly_ip  = "192.168.56.103"
    }
  }

  validation {
    condition     = length(var.nodes) >= 1
    error_message = "Define at least one VM node."
  }
}
