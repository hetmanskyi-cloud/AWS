# --- DynamoDB Table for Terraform State Locking --- #
# This file defines a DynamoDB table used for Terraform state file locking.
# The locking mechanism prevents multiple users from making concurrent changes to the state file.

resource "aws_dynamodb_table" "terraform_locks" {
  # --- Table Name --- #
  # Construct the table name dynamically using a project-specific prefix and a random suffix for uniqueness.
  name = "${lower(var.name_prefix)}-terraform-locks-${random_string.suffix.result}"

  # --- Billing Mode --- #
  # PAY_PER_REQUEST: Ensures that you only pay for the read/write operations you use.
  # Ideal for infrequent Terraform runs or projects with variable usage.
  billing_mode = "PAY_PER_REQUEST"

  # --- Key Schema --- #
  # Hash Key: "LockID" is used as the primary key for the table.
  hash_key = "LockID"

  # --- TTL Configuration --- #
  # Enables automatic deletion of expired items using the Time-to-Live (TTL) feature.
  ttl {
    attribute_name = "ExpirationTime" # Attribute that stores expiration timestamps in Unix format.
    enabled        = true             # Enables TTL for the table.
  }

  # --- Stream Configuration --- #
  # Enables DynamoDB Streams to track item changes (e.g., creation or modification).
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES" # Provides both new and old item images for Lambda to process.

  # --- Encryption --- #
  # Enables server-side encryption using an AWS KMS key for data protection.
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn # KMS key dynamically passed as a variable.
  }

  # --- Point-in-Time Recovery (PITR) --- #
  # Enables point-in-time recovery to allow restoration of the table
  # to any point within the past 35 days. This is a best practice
  # to protect against accidental deletions or modifications.
  point_in_time_recovery {
    enabled = true
  }

  # --- Attribute Definitions --- #
  # Defines the attributes for the table schema.
  # "LockID" is a string type attribute used as the hash key.
  # "ExpirationTime" is a numeric type attribute used for TTL.
  attribute {
    name = "LockID"
    type = "S" # S: String type.
  }

  attribute {
    name = "ExpirationTime"
    type = "N" # N: Numeric type (Unix timestamp for TTL).
  }

  # --- Local Secondary Index (LSI) --- #
  # Adds ExpirationTime as a secondary index for TTL compatibility and future use.
  local_secondary_index {
    name            = "LockID-ExpirationTime-Index" # Name of the index.
    projection_type = "ALL"                         # Includes all attributes in the index.
    range_key       = "ExpirationTime"              # ExpirationTime serves as the range key.
  }

  # --- Tags --- #
  # Add descriptive tags for resource identification and organization.
  tags = {
    Name        = "${var.name_prefix}-terraform-locks" # Dynamic tag for table name.
    Environment = var.environment                      # Tag indicating the deployment environment (e.g., dev, prod).
  }
}

# --- Notes --- #
# 1. **Purpose**:
#    - This DynamoDB table is designed exclusively for Terraform state locking to ensure safe and consistent state management.
# 2. **Best Practices**:
#    - Enable TTL to automatically clean up expired lock entries.
#    - Use server-side encryption with a dedicated KMS key for enhanced data security.
#    - Enable point-in-time recovery to protect against accidental data loss.
# 3. **Integration**:
#    - The `aws_dynamodb_table.terraform_locks` resource is referenced in `s3/outputs.tf` for exposing table details.
#    - The DynamoDB Streams are connected to a Lambda function defined in `s3/lambda.tf` for TTL automation.