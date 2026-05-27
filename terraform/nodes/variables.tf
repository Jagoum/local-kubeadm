variable "control_plane_name" {
  description = "Name of the control plane node"
  type        = string
  default     = "k8s-control-plane"
}

variable "worker_names" {
  description = "Names of the worker nodes"
  type        = list(string)
  default     = ["k8s-worker-1", "k8s-worker-2"]
}

variable "ubuntu_image" {
  description = "Ubuntu image to use for VMs"
  type        = string
  default     = "images:ubuntu/24.04/cloud"
}

variable "incus_network" {
  description = "Incus network to use"
  type        = string
  default     = "incusbr0"
}

variable "incus_pool" {
  description = "Incus storage pool to use"
  type        = string
  default     = "default"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = ""
}

variable "node_password" {
  description = "Password for the ubuntu user"
  type        = string
  default     = "ubuntu"
  sensitive   = true
}
