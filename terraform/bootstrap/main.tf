# Local logic moved out of Provisioning and into Bootstrap
locals {
  control_plane_ip = data.terraform_remote_state.nodes.outputs.control_plane_ip
  worker_ips       = data.terraform_remote_state.nodes.outputs.worker_ips
}

# Generate inventory file for Ansible
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../../ansible/inventory/hosts.ini"
  
  content = <<-EOT
    [all:vars]
    ansible_user=ubuntu
    ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
    ansible_python_interpreter=/usr/bin/python3
    kubernetes_version=${var.kubernetes_version}
    calico_version=${var.calico_version}
    pod_network_cidr=${var.pod_network_cidr}
    service_cidr=${var.service_cidr}
    
    [control_plane]
    ${var.control_plane_name} ansible_host=${local.control_plane_ip}
    
    [workers]
    %{ for i, worker in var.worker_names ~}
    ${worker} ansible_host=${local.worker_ips[i]}
    %{ endfor ~}
    
    [k8s_cluster:children]
    control_plane
    workers
  EOT
}

# Run Ansible playbook
resource "null_resource" "ansible_provision" {
  # Trigger on VM changes via the remote state IDs property
  triggers = {
    control_plane_id = data.terraform_remote_state.nodes.outputs.control_plane_id
    worker_ids       = join(",", data.terraform_remote_state.nodes.outputs.worker_ids)
    inventory_hash   = local_file.ansible_inventory.id
    k8s_version      = var.kubernetes_version
    calico_version   = var.calico_version
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/../..
      if [ ! -d ".venv" ]; then
        python3 -m venv .venv
        .venv/bin/pip install --upgrade pip
        .venv/bin/pip install ansible
      fi
      .venv/bin/ansible-galaxy collection install -r ansible/requirements.yml
      cd ansible
      ../.venv/bin/ansible-playbook -i inventory/hosts.ini site.yml \
        --extra-vars '{"control_plane_endpoint": "${local.control_plane_ip}"}'
    EOT
  }
}
