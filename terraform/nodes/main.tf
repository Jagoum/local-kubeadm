# Control Plane VM
resource "incus_instance" "control_plane" {
  name  = var.control_plane_name
  image = var.ubuntu_image
  type  = "virtual-machine"

  config = {
    "limits.cpu"    = 2
    "limits.memory" = "5GiB"
    "user.user-data" = templatefile("${path.module}/cloud-init/control-plane.yaml.tpl", {
      ssh_public_key = var.ssh_public_key
      hostname       = var.control_plane_name
      node_password  = var.node_password
    })
  }

  wait_for {
    type  = "delay"
    delay = "60s"
  }

  wait_for {
    type = "ipv4"
    nic  = "enp5s0"
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.incus_pool
      size = "20GiB"
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      name    = "eth0"
      network = var.incus_network
    }
  }
}

# Worker VMs
resource "incus_instance" "workers" {
  count = length(var.worker_names)
  
  name  = var.worker_names[count.index]
  image = var.ubuntu_image
  type  = "virtual-machine"

  config = {
    "limits.cpu"    = 3
    "limits.memory" = "5GiB"
    "user.user-data" = templatefile("${path.module}/cloud-init/worker.yaml.tpl", {
      ssh_public_key = var.ssh_public_key
      hostname       = var.worker_names[count.index]
      node_password  = var.node_password
    })
  }

  wait_for {
    type  = "delay"
    delay = "60s"
  }

  wait_for {
    type = "ipv4"
    nic  = "enp5s0"
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.incus_pool
      size = "40GiB"
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      name    = "eth0"
      network = var.incus_network
    }
  }
}
