# --- DynamoDB Table for Terraform State Locking ---
# Creates a DynamoDB table to handle state locking for Terraform
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${lower(var.name_prefix)}-terraform-locks-${random_string.suffix.result}"
  billing_mode = "PAY_PER_REQUEST" # Pay-per-request billing
  hash_key     = "LockID"

  # Enable server-side encryption for DynamoDB with KMS key
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn # KMS key for DynamoDB encryption
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.name_prefix}-terraform-locks"
    Environment = var.environment
  }
}
