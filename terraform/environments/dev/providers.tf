# --- Terraform and Provider Configuration --- #
# This file defines the core Terraform settings and configures all necessary providers
# for the infrastructure, including aliases for multi-region and global service management.

# --- Required Providers Block --- #
# Declares all providers used in this project and enforces maximum version constraints
# to ensure stable and reproducible builds.
terraform {
  required_version = "~> 1.12" # Constrains version to >= 1.12.0 and < 2.0.0

  # For managing all primary AWS resources (VPC, EC2, RDS, etc.)
  required_providers {
    aws = {
      source  = "hashicorp/aws" # Source for the AWS provider
      version = ">= 5.0"        # Required version for AWS provider
    }
    # For generating random values for secrets and unique names
    random = {
      source  = "hashicorp/random" # Source for the Random provider
      version = ">= 3.0"           # Required version for Random provider
    }
    # The Null provider is used for resources that do not create any remote objects,
    # For using null_resource to trigger local scripts (e.g., building Lambda layers)
    null = {
      source  = "hashicorp/null" # Source for the Null provider
      version = ">= 3.0"         # Required version for Null provider
    }
    # For creating ZIP archives from source files (e.g., for Lambda deployment packages)
    archive = {
      source  = "hashicorp/archive" # Source for the Archive provider
      version = ">= 2.0"            # Required version for Archive provider
    }
    # For managing TLS certificates
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    # The template provider exposes data sources to use templates to generate strings for other Terraform resources or outputs
    template = {
      source  = "hashicorp/template"
      version = ">= 2.2.0"
    }
    # For executing external scripts and commands, such as fetching data from APIs or running local scripts
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3.0"
    }
    # The HTTP provider is used to make HTTP requests, such as fetching remote files or APIs
    http = {
      source  = "hashicorp/http"
      version = "~> 3.5"
    }
  }
}

# --- Provider Configurations --- #
# Defines specific configurations for each provider, including aliases for different regions.

# --- Default AWS Provider (Primary Region) --- #
# This is the main provider for the primary deployment region (e.g., eu-west-1).
# Configure the AWS alias provider and set the default region from a variable
provider "aws" {
  alias   = "default"
  region  = var.aws_region
  profile = "default"

  # Common tags applied to all AWS resources (centralized in metadata.tf)
  default_tags {
    tags = local.common_tags
  }
}

# --- Replication AWS Provider (DR Region) --- #
# This provider alias is used for resources in the replication region (e.g., for S3 backups)
# Configure the AWS alias provider and set the region for the replication bucket
provider "aws" {
  alias   = "replication"
  region  = var.replication_region
  profile = "default"

  default_tags {
    tags = local.common_tags
  }
}

# --- CloudFront AWS Provider (us-east-1) --- #
# This provider alias is explicitly configured for the us-east-1 region.
# It is required for managing global services like CloudFront, ACM for CloudFront, and WAFv2 for CloudFront
# CloudFront WAF always must be created in us-east-1
provider "aws" {
  alias   = "cloudfront"
  region  = "us-east-1"
  profile = "default"

  default_tags {
    tags = local.common_tags
  }
}

# --- Random Provider --- #
# Used for generating random strings and passwords for secrets and unique names.
provider "random" {

  # No configuration required as this provider generates random values
}

# --- Null Provider --- #
# This provider is used for resources that don't create any remote objects,
# like 'null_resource', which we use as a trigger for local-exec provisioners.
provider "null" {

  # No configuration is required for this provider.
}

# --- Archive Provider --- #
# This provider is used as a data source to create ZIP archives on the fly,
# for example, for Lambda deployment packages.
provider "archive" {

  # No configuration is required for this provider.
}

# --- TLS Provider --- #
# This provider is used for managing TLS certificates.
provider "tls" {

  # No configuration is required for this provider.
}

# --- Template Provider --- #
provider "template" {

  # No configuration is required for this provider.
}

# --- External Provider --- #
provider "external" {

  # No configuration is required for this provider.
}

# --- HTTP Provider --- #
provider "http" {

  # No configuration is required for this provider.
}

# --- Notes --- #
# 1. Provider Aliases:
#    - We use aliases (`replication`, `cloudfront`) to instruct Terraform to create specific
#      resources in different AWS regions than the default one. This is essential for
#      managing global services and cross-region replication within a single configuration.
#
# 2. Centralized Tagging:
#    - The `default_tags` block in each AWS provider configuration automatically applies
#      a common set of tags (defined in `metadata.tf`) to all taggable resources.
#      This ensures consistency and simplifies resource tracking and cost allocation.
#
# 3. Version Pinning:
#    - The `required_providers` block locks down the major versions of our providers.
#    - This is a critical best practice that prevents breaking changes from new provider
#      versions from automatically being introduced, leading to more stable infrastructure.
