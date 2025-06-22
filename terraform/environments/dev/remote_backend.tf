# --- Remote Backend Configuration (Commented) --- #
# This file defines a remote backend for Terraform state management.
# Uncomment and configure the backend block to enable remote state storage.
#
## Example:
#
# terraform {
#   backend "s3" {
#     bucket         = "<S3_BUCKET_NAME>"                       # Replace with the name of your S3 bucket for state storage
#     key            = "state/<ENVIRONMENT>/terraform.tfstate"  # Replace <ENVIRONMENT> with your environment (e.g., dev, prod)
#     region         = "<AWS_REGION>"                           # Replace with your AWS region (e.g., eu-west-1)
#     dynamodb_table = "<DYNAMODB_TABLE_NAME>"                  # Replace with the name of your DynamoDB table for state locking
#     encrypt        = true                                     # Encrypt the state file at rest
#   }
# }
#
# --- Notes --- #
# 1. Replace <S3_BUCKET_NAME> and <DYNAMODB_TABLE_NAME> with the actual names of your S3 bucket and DynamoDB table.
# 2. Ensure all of these resources are created before uncommenting the backend configuration.
# 3. Run `terraform apply` for the S3 module to create the required resources.
# 4. After uncommenting, initialize the backend with `terraform init -reconfigure`.
# 5. This configuration ensures centralized state management with state locking for improved collaboration.
# 6. The backend block must be uncommented **before** running Terraform commands in a clean environment.
#    Terraform cannot migrate state automatically without an initialized backend.
