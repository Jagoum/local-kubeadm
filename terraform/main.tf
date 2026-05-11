# Terraform configuration for provisioning Multipass VMs for kubeadm cluster
# This configuration creates 3 VMs: 1 control plane and 2 worker nodes
# Production-grade setup with Calico CNI

terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    multipass = {
      source  = "todoroff/multipass"
      version = ">= 1.4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
  }
}

# Provider configuration for Multipass
provider "multipass" {
  # Uses default multipass installation
}

# Control Plane VM
resource "multipass_instance" "control_plane" {
  name  = var.control_plane_name
  image = var.ubuntu_image
  
  # 2 vCPU, 4GB memory, 20GB disk
  cpus   = 2
  memory = "4G"
  disk   = "20G"
  
  # Cloud-init configuration for SSH and basic setup
  cloud_init = templatefile("${path.module}/cloud-init/control-plane.yaml.tpl", {
    ssh_public_key = var.ssh_public_key
    hostname       = var.control_plane_name
  })
}

# Worker VMs
resource "multipass_instance" "workers" {
  count = length(var.worker_names)
  
  name  = var.worker_names[count.index]
  image = var.ubuntu_image
  
  # 2 vCPU, 3GB memory, 40GB disk
  cpus   = 2
  memory = "3G"
  disk   = "40G"
  
  # Cloud-init configuration for SSH and basic setup
  cloud_init = templatefile("${path.module}/cloud-init/worker.yaml.tpl", {
    ssh_public_key = var.ssh_public_key
    hostname       = var.worker_names[count.index]
  })
}

# Generate inventory file for Ansible
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory/hosts.ini"
  
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
    ${var.control_plane_name} ansible_host=${multipass_instance.control_plane.ipv4[0]}
    
    [workers]
    %{ for i, worker in var.worker_names ~}
    ${worker} ansible_host=${multipass_instance.workers[i].ipv4[0]}
    %{ endfor ~}
    
    [k8s_cluster:children]
    control_plane
    workers
  EOT
  
  depends_on = [
    multipass_instance.control_plane,
    multipass_instance.workers
  ]
}

# Run Ansible playbook after VM provisioning
# Terraform only triggers Ansible, doesn't track state of what's in the VM
# Uses Python virtual environment for Ansible execution
resource "null_resource" "ansible_provision" {
  # Trigger on VM changes
  triggers = {
    control_plane_id = multipass_instance.control_plane.id
    worker_ids        = join(",", [for w in multipass_instance.workers : w.id])
    inventory_hash    = local_file.ansible_inventory.id
    k8s_version       = var.kubernetes_version
    calico_version    = var.calico_version
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      cd ${path.module}/..
      if [ ! -d ".venv" ]; then
        python3 -m venv .venv
        .venv/bin/pip install --upgrade pip
        .venv/bin/pip install ansible
      fi
      .venv/bin/ansible-galaxy collection install -r ansible/requirements.yml
      cd ansible
      ../.venv/bin/ansible-playbook -i inventory/hosts.ini site.yml \
        --extra-vars '{"control_plane_endpoint": "${multipass_instance.control_plane.ipv4[0]}"}'
    EOT
  }
  
  depends_on = [
    local_file.ansible_inventory
  ]
}