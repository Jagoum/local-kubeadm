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
    playbook_hash    = filesha256("${path.module}/../../ansible/site.yml")
    vars_hash        = filesha256("${path.module}/../../ansible/group_vars/all.yml")
    inventory_hash   = local_file.ansible_inventory.id
    worker_ids       = join(",", data.terraform_remote_state.nodes.outputs.worker_ids)
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
        --extra-vars '{"control_plane_endpoint": "${local.control_plane_ip}", "argocd_repo_url": "${var.gitops_repo_url}", "argocd_target_revision": "${var.gitops_target_revision}", "github_pat": "${var.github_pat}"}'
    EOT
  }
}

# Apply OpenStack ArgoCD manifests from this repository
resource "null_resource" "openstack_argocd_apps" {
  depends_on = [null_resource.ansible_provision]

  triggers = {
    # Re-applies whenever any app manifest changes in this repo
    apps_hash = sha256(join("", [
      for f in sort(fileset("${path.module}/../../argocd", "**/*.yaml")) : 
        filesha256("${path.module}/../../argocd/${f}")
    ]))
    worker_ids = join(",", data.terraform_remote_state.nodes.outputs.worker_ids)
  }

  # Delete existing ArgoCD applications that are not managed by Terraform
  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=~/.kube/config.local
      
      # Delete the bootstrap app (App of Apps pattern - no longer used)
      kubectl delete application bootstrap-openstack -n argocd --ignore-not-found=true
      
      # Delete all existing applications to let Terraform manage them
      kubectl delete application --all -n argocd --ignore-not-found=true
      
      # Wait for applications to be deleted
      sleep 5
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      export KUBECONFIG=~/.kube/config.local
      
      # Apply AppProject first (so apps can reference it)
      kubectl apply -f ${path.module}/../../argocd/project.yaml

      # Ensure the openstack namespace exists
      kubectl get ns openstack 2>/dev/null || kubectl create ns openstack

      # Apply all application manifests from this repository
      kubectl apply -f ${path.module}/../../argocd/apps/
    EOT
  }
}
