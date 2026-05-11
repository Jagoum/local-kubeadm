# Terraform outputs for kubeadm cluster

output "control_plane_ip" {
  description = "IP address of the control plane node"
  value       = multipass_instance.control_plane.ipv4[0]
}

output "worker_ips" {
  description = "IP addresses of the worker nodes"
  value       = { for i, worker in var.worker_names : worker => multipass_instance.workers[i].ipv4[0] }
}

output "ansible_inventory_path" {
  description = "Path to the generated Ansible inventory file"
  value       = local_file.ansible_inventory.filename
}

output "cluster_info" {
  description = "Cluster connection information"
  value = {
    control_plane_endpoint = multipass_instance.control_plane.ipv4[0]
    kubernetes_version     = var.kubernetes_version
    calico_version         = var.calico_version
    pod_network_cidr       = var.pod_network_cidr
  }
}

output "ssh_access" {
  description = "SSH access information"
  value = {
    user = "ubuntu"
    command_example = "ssh ubuntu@${multipass_instance.control_plane.ipv4[0]}"
  }
}