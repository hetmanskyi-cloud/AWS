# --- Main Configuration for S3 Buckets --- #
# This file defines the S3 buckets required for the project.
# Buckets include:
# 1. terraform_state: To store the Terraform state file.
# 2. wordpress_media: To store media assets for WordPress in prod environment.
# 3. scripts: To store project-related scripts.
# 4. logging: To store logs for all buckets.
# 5. ami: To store golden AMI images for the project.
# 6. replication: Serves as the destination for cross-region replication.
#    - This bucket is created only in the `prod` environment and when replication is enabled (`enable_s3_replication = true`).
#    - It stores replicated objects from source buckets, ensuring data redundancy across regions.

# --- Combine all environment and replication logic here --- #
# We previously defined locals in access.tf and policies.tf. Now we unify them here.
locals {
  # Base buckets (resource references) common to both dev and prod
  global_base_buckets = {
    terraform_state = aws_s3_bucket.terraform_state
    scripts         = aws_s3_bucket.scripts
    logging         = aws_s3_bucket.logging
    ami             = aws_s3_bucket.ami
  }

  # Add wordpress_media only in prod
  global_prod_buckets = var.environment == "prod" ? merge(local.global_base_buckets, {
    wordpress_media = aws_s3_bucket.wordpress_media[0]
  }) : local.global_base_buckets

  # Add replication if enabled in prod
  global_prod_with_replication_buckets = var.environment == "prod" && var.enable_s3_replication ? merge(local.global_prod_buckets, {
    replication = aws_s3_bucket.replication[0]
  }) : local.global_prod_buckets

  # For IAM replication policy (arrays of ARNs)
  # Base ARNs for replication configuration
  global_base_replication_resources = [
    aws_s3_bucket.terraform_state.arn,
    "${aws_s3_bucket.terraform_state.arn}/*",
    aws_s3_bucket.scripts.arn,
    "${aws_s3_bucket.scripts.arn}/*"
  ]

  # Add wordpress_media ARNs if in prod
  global_prod_replication_resources = var.environment == "prod" ? concat(
    local.global_base_replication_resources,
    [
      aws_s3_bucket.wordpress_media[0].arn,
      "${aws_s3_bucket.wordpress_media[0].arn}/*"
    ]
  ) : local.global_base_replication_resources

  # Lifecycle and versioning require IDs
  global_base_buckets_ids = {
    terraform_state = aws_s3_bucket.terraform_state.id
    scripts         = aws_s3_bucket.scripts.id
    logging         = aws_s3_bucket.logging.id
    ami             = aws_s3_bucket.ami.id
  }

  global_prod_buckets_ids = var.environment == "prod" ? merge(local.global_base_buckets_ids, {
    wordpress_media = aws_s3_bucket.wordpress_media[0].id
  }) : local.global_base_buckets_ids

  global_prod_with_replication_buckets_ids = var.environment == "prod" && var.enable_s3_replication ? merge(local.global_prod_buckets_ids, {
    replication = aws_s3_bucket.replication[0].id
  }) : local.global_prod_buckets_ids

  # Source bucket replication policy (IDs)
  global_base_replication_source = {
    terraform_state = aws_s3_bucket.terraform_state.id
    scripts         = aws_s3_bucket.scripts.id
    logging         = aws_s3_bucket.logging.id
    ami             = aws_s3_bucket.ami.id
  }

  global_prod_replication_source = var.environment == "prod" ? merge(local.global_base_replication_source, {
    wordpress_media = aws_s3_bucket.wordpress_media[0].id
  }) : local.global_base_replication_source

  global_final_replication_source = var.environment == "prod" && var.enable_s3_replication ? merge(local.global_prod_replication_source, {
    replication = aws_s3_bucket.replication[0].id
  }) : local.global_prod_replication_source

  # Original bucket_map remains as is, used for notifications and force_https
  bucket_map = merge(
    {
      "terraform_state" = {
        id  = aws_s3_bucket.terraform_state.id
        arn = aws_s3_bucket.terraform_state.arn
      }
      "scripts" = {
        id  = aws_s3_bucket.scripts.id
        arn = aws_s3_bucket.scripts.arn
      }
      "logging" = {
        id  = aws_s3_bucket.logging.id
        arn = aws_s3_bucket.logging.arn
      }
      "ami" = {
        id  = aws_s3_bucket.ami.id
        arn = aws_s3_bucket.ami.arn
      }
    },
    var.environment == "prod" ? {
      "wordpress_media" = {
        id  = aws_s3_bucket.wordpress_media[0].id
        arn = aws_s3_bucket.wordpress_media[0].arn
      }
    } : {},
    var.environment == "prod" && var.enable_s3_replication ? {
      "replication" = {
        id  = aws_s3_bucket.replication[0].id
        arn = aws_s3_bucket.replication[0].arn
      }
    } : {}
  )
}

# --- Terraform Configuration --- #
# This block defines the required Terraform providers and their versions.
# It ensures compatibility and manages aliases for multiple provider configurations.
# Note: The main AWS provider configuration is defined in the `providers.tf` file in the root/main block.
# This block only specifies requirements and aliases relevant to the S3 module.

terraform {
  required_providers {
    # AWS Provider Configuration
    aws = {
      source                = "hashicorp/aws"   # Specifies the source for the AWS provider (HashiCorp registry)
      version               = "~> 5.0"          # Locks the AWS provider to major version 5.x to avoid breaking changes
      configuration_aliases = [aws.replication] # Allows the use of a named alias (aws.replication) for managing cross-region resources
    }
  }
}

# --- Terraform State S3 Bucket --- #
# This bucket is used to store the Terraform state file.
resource "aws_s3_bucket" "terraform_state" {
  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-terraform-state-${random_string.suffix.result}"

  # Dependency ensures logging bucket is created first
  depends_on = [aws_s3_bucket.logging]

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-terraform-state"
    Environment = var.environment
  }
}

# --- WordPress Media S3 Bucket --- #
# This bucket stores WordPress media files (e.g., images, videos) and created only in the prod environment.
resource "aws_s3_bucket" "wordpress_media" {
  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-wordpress-media-${random_string.suffix.result}"
  # Created only in prod environment
  count = var.environment == "prod" ? 1 : 0

  # Dependency ensures logging bucket is created first
  depends_on = [aws_s3_bucket.logging]

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-wordpress-media"
    Environment = var.environment
  }
}

# --- Scripts S3 Bucket --- #
# This bucket stores project-related scripts, organized in directories (e.g., wordpress/).
resource "aws_s3_bucket" "scripts" {
  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-scripts-${random_string.suffix.result}"

  # Dependency ensures logging bucket is created first
  depends_on = [aws_s3_bucket.logging]

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-scripts"
    Environment = var.environment
  }
}

# --- WordPress Directory in Scripts Bucket --- #
# This resource ensures the creation of a "wordpress/" folder
# in the "scripts" S3 bucket. The folder serves as a dedicated
# directory for storing WordPress-related setup and maintenance scripts.

resource "aws_s3_object" "wordpress_folder" {
  bucket = aws_s3_bucket.scripts.bucket # Specify the bucket where the folder will be created
  key    = "wordpress/"                 # Use a trailing slash to denote a directory

  # --- Notes --- #
  # 1. The "aws_s3_object" resource replaces the deprecated "aws_s3_bucket_object".
  # 2. The "key" field denotes the folder path within the bucket.
  # 3. While S3 has no true folders, the trailing slash creates a logical directory structure.
}

# --- Logging S3 Bucket --- #
# This bucket stores logs for all other buckets to ensure compliance and auditing.
resource "aws_s3_bucket" "logging" {
  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${var.name_prefix}-logging-${random_string.suffix.result}"

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-logging"
    Environment = var.environment
  }
}

# --- Replication S3 Bucket --- #
# This bucket serves as the destination for cross-region replication.
# It is created only in the prod environment and when replication is enabled (controlled by `enable_s3_replication`).
resource "aws_s3_bucket" "replication" {
  provider = aws.replication
  # Create the bucket only if both conditions are true
  count = var.environment == "prod" && var.enable_s3_replication ? 1 : 0

  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-replication-${random_string.suffix.result}"

  # Dependency ensures logging bucket is created first
  depends_on = [aws_s3_bucket.logging]

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-replication"
    Environment = var.environment
  }
}

# --- AMI S3 Bucket --- #
# This bucket stores golden AMI images for the project.
# AMI images are used as base templates for launching pre-configured EC2 instances.
resource "aws_s3_bucket" "ami" {
  # Unique bucket name using the name_prefix and a random suffix
  bucket = "${lower(var.name_prefix)}-ami-${random_string.suffix.result}"

  # Dependency ensures logging bucket is created first
  depends_on = [aws_s3_bucket.logging]

  # Tags for identification and cost tracking
  tags = {
    Name        = "${var.name_prefix}-ami"
    Environment = var.environment
  }
}

# --- Replication Configuration for Source Buckets --- #
# Applies replication rules only when the environment is `prod` and replication is enabled.
# Each source bucket will replicate its objects to the replication bucket.
resource "aws_s3_bucket_replication_configuration" "replication_config" {
  provider = aws.replication
  for_each = var.environment == "prod" && var.enable_s3_replication ? {
    terraform_state = aws_s3_bucket.terraform_state.id,
    wordpress_media = aws_s3_bucket.wordpress_media[0].id,
    scripts         = aws_s3_bucket.scripts.id,
    logging         = aws_s3_bucket.logging.id,
    ami             = aws_s3_bucket.ami.id
  } : {}
  # Applies replication rules only in prod environment and when replication is enabled

  bucket = each.value
  role   = aws_iam_role.replication_role[0].arn

  rule {
    id     = "${each.key}-replication"
    status = "Enabled"

    filter {
      prefix = "${each.key}/" # Logical folder structure in the replication bucket for each source bucket
    }

    destination {
      bucket        = aws_s3_bucket.replication[0].arn
      storage_class = "STANDARD"
    }
  }
}

# --- Random String Resource --- #
# Generates a unique 5-character suffix for bucket names.
resource "random_string" "suffix" {
  length  = 5     # Length of the random string
  special = false # Exclude special characters
  upper   = false # Exclude uppercase letters
  lower   = true  # Include lowercase letters
  numeric = true  # Include numeric digits
}

# --- S3 Bucket Notifications --- #
# Notifications are sent to the specified SNS topic whenever objects are created or deleted in the buckets.
# Notifications are applied only to buckets that exist in the current environment.
# - In `prod`, includes `wordpress_media` and `replication` (if replication is enabled).
# - In `dev`, limited to buckets: `terraform_state`, `scripts`, `logging`, and `ami`.

resource "aws_s3_bucket_notification" "bucket_notifications" {
  for_each = var.environment == "prod" ? local.bucket_map : {
    terraform_state = local.bucket_map.terraform_state,
    scripts         = local.bucket_map.scripts,
    logging         = local.bucket_map.logging,
    ami             = local.bucket_map.ami
  }

  # S3 bucket to which the notification applies
  bucket = each.value.id

  # Notification configuration for the bucket
  topic {
    topic_arn = var.sns_topic_arn                            # ARN of the SNS topic for notifications
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"] # Notify on object creation and deletion
  }
}

# --- Notes --- #
# 1. Cross-Region Replication:
#    - Enabled only in `prod` and when `enable_s3_replication` is set to `true`.
#    - Source buckets replicate their objects to separate folders in the replication bucket.
#    - The replication bucket is created in a different region to ensure data redundancy.
#
# 2. Dependencies (`depends_on`):
#    - Ensures that the logging bucket is created before other buckets.
#    - Prevents configuration errors in replication or notifications.
#
# 3. Logical structure for replication:
#    - Each source bucket replicates objects into a dedicated "folder" in the replication bucket using a `prefix` in the filter.
#
# 4. Notifications:
#    - Notifications apply only to buckets that exist in the current environment.
#
# 5. Unique bucket names:
#    - Prevents conflicts in the global namespace of S3.