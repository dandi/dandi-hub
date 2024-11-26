terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.76.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.33.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.16.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.3"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.4.0"
    }
  }
}