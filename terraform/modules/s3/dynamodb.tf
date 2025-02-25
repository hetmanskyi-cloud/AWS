# --- DynamoDB Table for Terraform State Locking --- #
# This file defines a DynamoDB table used for Terraform state file locking.
# The locking mechanism prevents multiple users from making concurrent changes to the state file.

resource "aws_dynamodb_table" "terraform_locks" {
  # Create the table only if the remote backend, S3 bucket for state, and DynamoDB are enabled.
  count = var.default_region_buckets["terraform_state"].enabled && var.enable_dynamodb ? 1 : 0

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

  # --- Tags --- #
  # Add descriptive tags for resource identification and organization.
  tags = {
    Name        = "${var.name_prefix}-terraform-locks" # Dynamic tag for table name.
    Environment = var.environment                      # Tag indicating the deployment environment (e.g., dev, prod).
  }
}

# --- Notes --- #
# 1. **Creation Logic**:
#    - The DynamoDB table is created only if `terraform_state` bucket enabled in `buckets`, and `enable_dynamodb` are all set to `true`.
# 2. **Purpose**:
#    - This DynamoDB table is designed exclusively for Terraform state locking.
# 3. **Best Practices**:
#    - Enable TTL to clean up expired lock entries automatically.
#    - Use KMS encryption for enhanced data security.
# 4. **Integration**:
#    - The DynamoDB table integrates with Lambda for TTL automation defined in `s3/lambda.tf`.