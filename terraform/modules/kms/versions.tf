# Terraform version and provider requirements
terraform {
  required_version = "~> 1.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
      configuration_aliases = [
        aws,
        aws.replication,
      ]
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}
