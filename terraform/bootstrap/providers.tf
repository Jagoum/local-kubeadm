terraform {
  required_version = ">= 1.0.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30.0"
    }
  }
}

data "terraform_remote_state" "nodes" {
  backend = "local"
  config = {
    path = "${path.module}/../nodes/terraform.tfstate"
  }
}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/config.local")
}
