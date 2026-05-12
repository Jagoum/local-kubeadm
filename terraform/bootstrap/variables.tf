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

variable "kubernetes_version" {
  type    = string
  default = "1.34"
}

variable "calico_version" {
  type    = string
  default = "3.31.4"
}

variable "pod_network_cidr" {
  type    = string
  default = "10.244.0.0/16"
}

variable "service_cidr" {
  type    = string
  default = "10.96.0.0/12"
}

variable "gitops_repo_url" {
  type    = string
  default = "https://opendev.org/openstack/openstack-helm.git"
}

variable "gitops_branch" {
  type    = string
  default = "HEAD"
}
