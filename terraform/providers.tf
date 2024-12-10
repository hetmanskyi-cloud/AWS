# --- Terraform and Providers Configuration --- #

# Configure the minimum required Terraform version and the AWS and Random providers
terraform {
  required_version = "~> 1.0" # Specifies the minimum Terraform version
  required_providers {
    aws = {
      source  = "hashicorp/aws" # Source for the AWS provider
      version = "~> 5.0"        # Required version for AWS provider
    }
    random = {
      source  = "hashicorp/random" # Source for the Random provider
      version = "~> 3.0"           # Required version for Random provider
    }
  }
}

# Configure the AWS provider and set the default region from a variable
provider "aws" {
  region = var.aws_region # AWS region variable is set in terraform.tfvars
}

# Configure the AWS alias provider and set the region for the replication bucket
provider "aws" {
  alias  = "replication"
  region = var.replication_region # AWS region variable for the replication bucket is set in terraform.tfvars
}

# Define the Random provider for generating random strings if needed
provider "random" {

  # No configuration required as this provider generates random values
}
