# --- Terraform and Providers Configuration --- #

# Configure the minimum required Terraform version and the AWS and Random providers
terraform {
  required_version = ">= 1.11.0" # Specifies the minimum Terraform version
  required_providers {
    aws = {
      source  = "hashicorp/aws" # Source for the AWS provider
      version = ">= 5.0"        # Required version for AWS provider
    }
    random = {
      source  = "hashicorp/random" # Source for the Random provider
      version = ">= 3.0"           # Required version for Random provider
    }
  }
}

# Configure the AWS provider and set the default region from a variable
provider "aws" {
  region  = var.aws_region
  profile = "default"

  default_tags {
    tags = {
      Project = "Test"
      Owner   = "Hetmanskyi"
    }
  }
}

# Configure the AWS alias provider and set the region for the replication bucket
provider "aws" {
  alias   = "replication"
  region  = var.replication_region
  profile = "default"

  default_tags {
    tags = {
      Project = "Test"
      Owner   = "Hetmanskyi"
    }
  }
}

# Define the Random provider for generating random strings if needed
provider "random" {

  # No configuration required as this provider generates random values
}