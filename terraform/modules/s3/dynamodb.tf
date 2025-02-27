# --- DynamoDB Table for Terraform State Locking --- #
# This file defines a DynamoDB table used for Terraform state file locking.
# The locking mechanism prevents multiple users from making concurrent changes to the state file.

# Local variable to check if terraform_state bucket is enabled
locals {
  terraform_state_bucket  = contains(keys(var.default_region_buckets), "terraform_state")                                # Check if terraform_state bucket exists
  terraform_state_enabled = local.terraform_state_bucket ? var.default_region_buckets["terraform_state"].enabled : false # Check if terraform_state bucket is enabled
  dynamodb_can_be_created = var.enable_dynamodb && local.terraform_state_enabled                                         # Condition: DynamoDB table can be created
}

resource "aws_dynamodb_table" "terraform_locks" {
  # Create the table only if remote backend, S3 bucket for state, and DynamoDB are enabled.
  count = local.dynamodb_can_be_created ? 1 : 0 # Conditional table creation

  # --- Table Name --- #
  # Table name is constructed dynamically using a project-specific prefix and a random suffix for uniqueness.
  name = "${lower(var.name_prefix)}-terraform-locks-${random_string.suffix.result}" # Dynamic table name

  # --- Billing Mode --- #
  # PAY_PER_REQUEST: You only pay for the read/write operations your application actually performs.
  billing_mode = "PAY_PER_REQUEST" # Billing mode: PAY_PER_REQUEST

  # --- Key Schema --- #
  # Hash Key: "LockID" is used as the primary key.
  hash_key = "LockID" # Hash key: LockID

  # --- TTL Configuration --- #
  # Enables automatic deletion of expired items using Time-to-Live (TTL).
  ttl {
    attribute_name = "ExpirationTime" # Attribute to store expiration timestamps in Unix format.
    enabled        = true             # Enable TTL
  }

  # --- Stream Configuration --- #
  # Enables DynamoDB Streams to capture item-level modifications (create, update, delete).
  stream_enabled   = true                 # Enable DynamoDB Streams
  stream_view_type = "NEW_AND_OLD_IMAGES" # Stream view type: NEW_AND_OLD_IMAGES (both new and old images)

  # --- Encryption --- #
  # Enables server-side encryption using an AWS KMS key for data protection.
  server_side_encryption {
    enabled     = true            # Enable encryption
    kms_key_arn = var.kms_key_arn # KMS key ARN (passed as a variable)
  }

  # --- Point-in-Time Recovery (PITR) --- #
  # Enables Point-in-Time Recovery to allow restoring table to any point within the past 35 days.
  point_in_time_recovery {
    enabled = true # Enable PITR
  }

  # --- Attribute Definitions --- #
  # Define attributes for table schema.
  attribute {
    name = "LockID" # Attribute name: LockID
    type = "S"      # Attribute type: String (S)
  }

  # --- Tags --- #
  # Add tags for resource identification and organization.
  tags = {
    Name        = "${var.name_prefix}-terraform-locks" # Tag: Table Name
    Environment = var.environment                      # Tag: Environment (e.g., dev, prod)
  }
}

# --- Notes --- #
# General notes for DynamoDB table.

# 1. Creation Logic: DynamoDB table is created only if terraform_state bucket is enabled and enable_dynamodb = true.
# 2. Purpose: Exclusively for Terraform state locking.
# 3. Best Practices: Enable TTL, KMS encryption.
# 4. Integration: Integrated with Lambda for TTL automation (`s3/lambda.tf`).