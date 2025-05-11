# --- Metadata --- #
# Centralized metadata used to generate consistent Name tags and project-wide tags across all modules.
# This file defines naming patterns and common tags. It simplifies tag management and enforces standardization.
# It is recommended to use this file for all modules to ensure consistent tagging across the project.

locals {
  # --- Resource Names --- #
  # Used as the "Name" tag for identifying resources by component
  resource_name_vpc                 = "${var.name_prefix}-vpc"                 # VPC resources
  resource_name_asg                 = "${var.name_prefix}-asg"                 # Auto Scaling Group
  resource_name_rds                 = "${var.name_prefix}-rds"                 # RDS instance
  resource_name_s3                  = "${var.name_prefix}-s3"                  # S3 buckets
  resource_name_kms                 = "${var.name_prefix}-kms"                 # KMS key
  resource_name_alb                 = "${var.name_prefix}-alb"                 # Application Load Balancer
  resource_name_redis               = "${var.name_prefix}-redis"               # ElastiCache Redis
  resource_name_cloudtrail          = "${var.name_prefix}-cloudtrail"          # CloudTrail logs
  resource_name_cloudwatch          = "${var.name_prefix}-cloudwatch"          # CloudWatch alarms
  resource_name_interface_endpoints = "${var.name_prefix}-interface_endpoints" # VPC Interface Endpoints
  resource_name_secrets             = "${var.name_prefix}-secrets"             # Secrets Manager
  resource_name_sns                 = "${var.name_prefix}-sns"                 # SNS topic

  # --- Common Tags --- #
  # Tags applied to all resources, merged with the "Name" tag per component
  common_tags = {
    Environment = var.environment # Environment name (e.g., "dev", "prod")
    Project     = var.project     # Project name or identifier
    Application = var.application # Application name (e.g., "wordpress")
    Owner       = var.owner       # Resource owner or responsible team
    ManagedBy   = "terraform"     # Marks all resources as managed by Terraform
  }

  # --- Merged Tags (Common + Name) --- #
  # Final tags used per component — to be passed into each module
  tags_vpc                 = merge(local.common_tags, { Name = local.resource_name_vpc })
  tags_asg                 = merge(local.common_tags, { Name = local.resource_name_asg })
  tags_rds                 = merge(local.common_tags, { Name = local.resource_name_rds })
  tags_s3                  = merge(local.common_tags, { Name = local.resource_name_s3 })
  tags_kms                 = merge(local.common_tags, { Name = local.resource_name_kms })
  tags_alb                 = merge(local.common_tags, { Name = local.resource_name_alb })
  tags_redis               = merge(local.common_tags, { Name = local.resource_name_redis })
  tags_cloudtrail          = merge(local.common_tags, { Name = local.resource_name_cloudtrail })
  tags_cloudwatch          = merge(local.common_tags, { Name = local.resource_name_cloudwatch })
  tags_interface_endpoints = merge(local.common_tags, { Name = local.resource_name_interface_endpoints })
  tags_secrets             = merge(local.common_tags, { Name = local.resource_name_secrets })
  tags_sns                 = merge(local.common_tags, { Name = local.resource_name_sns })
}

# --- Notes --- #
# - This file is placed in the root module (terraform/) and loaded automatically.
# - Values for variables `project`, `application`, `owner`, `environment`, and `name_prefix` are defined in terraform.tfvars.
# - Use `local.tags_*` in the main block to pass to each module (e.g., tags = local.tags_asg).
# - Modules can then use `merge({ Name = ... }, var.tags)` internally.
# - The `Name` tag is used for resource identification and should be unique within the AWS account.