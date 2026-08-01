terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "k8s-lab-tfstate-603613246440-eu-central-1"
    key          = "infrastructure/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}