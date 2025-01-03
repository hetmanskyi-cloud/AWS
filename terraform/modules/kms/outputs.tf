# --- KMS Key Outputs --- #

# Output the KMS key ARN for use in other modules
output "kms_key_arn" {
  description = "ARN of the KMS encryption key for other resources to use"
  value       = aws_kms_key.general_encryption_key.arn
}

# Output the KMS management role ARN
output "kms_management_role_arn" {
  description = "ARN of the IAM role for managing the KMS encryption key"
  value       = var.enable_kms_role ? aws_iam_role.kms_role[0].arn : null
}

# Output the KMS management policy ARN
output "kms_management_policy_arn" {
  description = "ARN of the KMS management policy for managing the encryption key"
  value       = var.enable_kms_role ? aws_iam_policy.kms_management_policy[0].arn : null
}

# Output the KMS alias name
output "kms_key_alias" {
  description = "The name of the KMS key alias"
  value       = aws_kms_alias.kms_alias[0].name
}

# Output the CloudWatch Alarm ARN
output "kms_decrypt_alarm_arn" {
  description = "The ARN of the CloudWatch Alarm for decrypt operations"
  value       = aws_cloudwatch_metric_alarm.kms_decrypt_alarm[0].arn
}

# --- Notes --- #
# 1. The `kms_key_arn` is always available as it represents the main encryption key.
# 2. The `kms_management_role_arn` and `kms_management_policy_arn` are conditional outputs and depend on the variable `enable_kms_management_role`.
#    - If `enable_kms_management_role` is `false`, these outputs will return `null`.
# 3. Ensure that dependent modules check for `null` values in outputs to avoid runtime errors.
# 4. These outputs are useful if other modules or resources need to reference the KMS management role or policy ARNs.