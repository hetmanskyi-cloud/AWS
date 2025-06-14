# --- Metadata --- #
# Centralized metadata used to apply consistent component-level tags across all Terraform modules and standalone resources.
# This file defines common tags (applied globally via providers.tf) and per-component `Component` tags.
# The `Name` tag is still defined manually in each resource for clarity and uniqueness.

locals {
  # --- Common Tags --- #
  # These tags are applied automatically to all resources via `default_tags` in providers.tf
  common_tags = {
    Environment = var.environment # Environment name (e.g., "dev", "prod")
    Project     = var.project     # Project name or identifier
    Application = var.application # Application name (e.g., "wordpress")
    Owner       = var.owner       # Resource owner or responsible team
    ManagedBy   = "terraform"     # Marks all resources as managed by Terraform
  }

  # --- Component Tags --- #
  # Passed explicitly to modules or used in standalone resource files to mark resource ownership
  # These tags assign a `Component` name to each group of related resources
  tags_alb                 = { Component = "alb" }
  tags_asg                 = { Component = "asg" }
  tags_redis               = { Component = "redis" }
  tags_interface_endpoints = { Component = "interface_endpoints" }
  tags_kms                 = { Component = "kms" }
  tags_rds                 = { Component = "rds" }
  tags_s3                  = { Component = "s3" }
  tags_vpc                 = { Component = "vpc" }
  tags_cloudtrail          = { Component = "cloudtrail" }
  tags_cloudwatch          = { Component = "cloudwatch" }
  tags_secrets             = { Component = "secrets" }
  tags_sns                 = { Component = "sns" }
  tags_cloudfront          = { Component = "cloudfront" }
}

# --- Notes --- #
# - `common_tags` are applied automatically to all resources via `default_tags` in providers.tf.
# - `tags_*` are passed to modules or used in top-level resource files to add a specific `Component` tag.
# - The `Name` tag must still be set per resource for uniqueness and readability.
# - This setup allows clear ownership and traceability across environments and resources.
# - The `ManagedBy` tag is set to "terraform" to indicate that these resources are managed by Terraform.
# - The `Component` tag is used to identify the specific component or module responsible for the resource.
# - The `Environment`, `Project`, `Application`, and `Owner` tags are used for organizational and billing purposes.