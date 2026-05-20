# Control Plane VM
resource "multipass_instance" "control_plane" {
  name  = var.control_plane_name
  image = var.ubuntu_image
  
  # 2 vCPU, 4GB memory, 20GB disk
  cpus   = 2
  memory = "5G"
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
  cpus   = 3
  memory = "5G"
  disk   = "40G"
  
  # Cloud-init configuration for SSH and basic setup
  cloud_init = templatefile("${path.module}/cloud-init/worker.yaml.tpl", {
    ssh_public_key = var.ssh_public_key
    hostname       = var.worker_names[count.index]
  })
}
