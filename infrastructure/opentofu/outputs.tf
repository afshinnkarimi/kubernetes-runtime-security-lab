output "nodes" {
  description = "VM names and host-only addresses."
  value = {
    for key, node in var.nodes : key => {
      name        = node.name
      hostonly_ip = node.hostonly_ip
      ssh_command = "ssh labadmin@${node.hostonly_ip}"
    }
  }
}

output "ssh_user" {
  value = "labadmin"
}
