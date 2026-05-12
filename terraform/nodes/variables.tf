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
  default     = "24.04"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = ""
}
