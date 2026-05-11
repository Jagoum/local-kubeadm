# Terraform variables for kubeadm cluster provisioning

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
  description = "SSH public key for VM access (leave empty to use default)"
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "Kubernetes version to install (LTS: 1.31, 1.32, 1.33, 1.34, 1.35 available)"
  type        = string
  default     = "1.31"
}

variable "calico_version" {
  description = "Calico CNI version (3.31.4 LTS - use full version for URL)"
  type        = string
  default     = "3.31.4"
}

variable "pod_network_cidr" {
  description = "Pod network CIDR for Calico (avoid Multipass default ranges)"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Service network CIDR (safe for Multipass)"
  type        = string
  default     = "10.96.0.0/12"
}