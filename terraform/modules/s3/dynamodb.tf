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
  # Sort Key: "ExpirationTime" is used as the secondary key for TTL purposes.
  hash_key  = "LockID"
  range_key = "ExpirationTime" # Sort key for indexing ExpirationTime.

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
  # Allows recovery of data to a specific point in time within the last 35 days.
  # Recommended for ensuring data durability in case of accidental writes or deletions.
  point_in_time_recovery {
    enabled = true
  }

  # --- Attribute Definitions --- #
  # Defines the attributes for the table schema.
  # "LockID" is a string type attribute used as the hash key.
  # "ExpirationTime" is a numeric type attribute used for TTL and as a sort key.
  attribute {
    name = "LockID"
    type = "S" # S: String type.
  }

  attribute {
    name = "ExpirationTime"
    type = "N" # N: Numeric type (Unix timestamp for TTL).
  }

  # --- Tags --- #
  # Add descriptive tags for resource identification and organization.
  tags = {
    Name        = "${var.name_prefix}-terraform-locks" # Dynamic tag for table name.
    Environment = var.environment                      # Tag indicating the deployment environment (e.g., dev, prod).
  }
}

# --- Notes --- #
# 1. The DynamoDB table is used exclusively for Terraform state locking to prevent concurrent operations.
# 2. TTL ensures expired lock entries are automatically deleted to avoid "stale" locks.
# 3. Adding "ExpirationTime" as a sort key ensures compatibility with TTL requirements.
# 4. KMS encryption ensures that data in the table is secure at rest.
# 5. Point-in-Time Recovery is a best practice for critical tables to ensure data can be recovered in case of accidental changes.
# 6. DynamoDB Streams are enabled to allow processing of item changes (e.g., by AWS Lambda).