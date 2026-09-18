terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.65.0"
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
  }

  required_version = ">= 1.5.7"
}
