terraform {
  required_version = ">= 1.6.0"

  # terraform_data is built into Terraform/OpenTofu; no third-party
  # VirtualBox provider is required.
}

locals {
  nodes                   = var.nodes
  rocky_image_path        = pathexpand(var.rocky_image_path)
  rocky_image_file_sha256 = filesha256(local.rocky_image_path)
}

resource "terraform_data" "node" {
  for_each = local.nodes

  input = merge(each.value, { vm_root_dir = var.vm_root_dir })

  triggers_replace = {
    name                    = each.value.name
    cpus                    = tostring(each.value.cpus)
    memory_mb               = tostring(each.value.memory_mb)
    disk_size_mb            = tostring(each.value.disk_size_mb)
    hostonly_ip             = each.value.hostonly_ip
    rocky_image_path        = local.rocky_image_path
    rocky_image_sha256      = var.rocky_image_sha256
    rocky_image_file_sha256 = local.rocky_image_file_sha256
    hostonly_adapter        = var.hostonly_adapter
    vm_root_dir             = var.vm_root_dir
    ssh_public_key_sha      = filesha256(pathexpand(var.ssh_public_key_path))
  }

  provisioner "local-exec" {
    command = join(" ", [
      "bash",
      "'${path.module}/scripts/create-vm.sh'",
      "'${each.value.name}'",
      "'${each.value.cpus}'",
      "'${each.value.memory_mb}'",
      "'${each.value.disk_size_mb}'",
      "'${each.value.hostonly_ip}'",
      "'${var.hostonly_adapter}'",
      "'${var.vm_root_dir}'",
      "'${local.rocky_image_path}'",
      "'${var.rocky_image_sha256}'",
      "'${pathexpand(var.ssh_public_key_path)}'"
    ])
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when = destroy

    command     = "bash '${path.module}/scripts/destroy-vm.sh' '${self.input.name}' '${self.input.vm_root_dir}'"
    interpreter = ["/bin/bash", "-c"]
  }
}
