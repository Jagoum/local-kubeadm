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
  description = "Git repository URL for ArgoCD applications (source of truth)"
  type        = string
  default     = "https://github.com/skyengpro/openstack-deployment.git"
}

variable "gitops_target_revision" {
  description = "Git branch, tag, or commit to use for ArgoCD applications"
  type        = string
  default     = "main"
}

variable "github_pat" {
  description = "GitHub Personal Access Token for private repository authentication (leave empty for public repos)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_openstack" {
  description = "Whether to deploy OpenStack applications via ArgoCD during bootstrap"
  type        = bool
  default     = false
}

# Component Toggles
variable "enable_metallb" {
  description = "Whether to deploy MetalLB"
  type        = bool
  default     = true
}

variable "enable_nginx_ingress" {
  description = "Whether to deploy Nginx Ingress"
  type        = bool
  default     = true
}

variable "enable_longhorn" {
  description = "Whether to deploy Longhorn"
  type        = bool
  default     = true
}

variable "enable_argocd" {
  description = "Whether to deploy ArgoCD"
  type        = bool
  default     = true
}
