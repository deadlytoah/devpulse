terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.47.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.4"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.6"
    }

    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.0"
    }
  }

  required_version = "~> 1.3"
}
