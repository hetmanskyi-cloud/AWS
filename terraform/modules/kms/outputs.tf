# --- KMS Key Outputs --- #

# Output the KMS key ARN for use in other modules
output "kms_key_arn" {
  description = "ARN of the KMS encryption key for other resources to use"
  value       = aws_kms_key.general_encryption_key.arn
}
