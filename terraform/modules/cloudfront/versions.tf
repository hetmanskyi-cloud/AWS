# Terraform version and provider requirements
terraform {
  required_version = "~> 1.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [
        aws,            # Default AWS provider alias
        aws.cloudfront, # Alias for AWS provider configured to us-east-1
      ]
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.5"
    }
  }
}
