terraform {
  required_version = ">= 1.0.0"
  required_providers {
    multipass = {
      source  = "todoroff/multipass"
      version = ">= 1.4.0"
    }
  }
}

provider "multipass" {}
