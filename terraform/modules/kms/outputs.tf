# --- KMS Key Outputs --- #

# --- KMS Key ARN --- #
# Always available. Represents the ARN of the main encryption key.
output "kms_key_arn" {
  description = "ARN of the KMS encryption key for other resources to use"
  value       = aws_kms_key.general_encryption_key.arn
}

# --- KMS Key ID --- #
# Always available. Represents the ID of the main encryption key.
output "kms_key_id" {
  description = "ID of the KMS encryption key for other resources to use"
  value       = aws_kms_key.general_encryption_key.id
}

# --- KMS Replica Key ARN --- #
# ARN of the replica KMS key in the replication region
output "kms_replica_key_arn" {
  description = "ARN of the replica KMS key in the replication region"
  value       = length(aws_kms_replica_key.replica_key) > 0 ? aws_kms_replica_key.replica_key[0].arn : null
}

# --- Enable KMS Role --- #
# Indicates whether the IAM role and policy for KMS interaction are created.
output "enable_kms_role" {
  description = "Enable or disable the creation of IAM role and policy for KMS interaction"
  value       = var.enable_kms_role
}

# --- KMS Management Role ARN --- #
# Returns null if enable_kms_role = false.
# Note: Ensure dependent modules handle null values to avoid runtime errors.
output "kms_management_role_arn" {
  description = <<EOT
ARN of the IAM role for managing the KMS encryption key.
Returns null if `enable_kms_role` is false.
Ensure dependent modules verify this output before using it.
EOT
  value       = var.enable_kms_role ? aws_iam_role.kms_role["kms_role"].arn : null
}

# --- KMS Management Policy ARN --- #
# Returns null if enable_kms_role = false.
# Note: Ensure dependent modules handle null values to avoid runtime errors.
output "kms_management_policy_arn" {
  description = <<EOT
ARN of the KMS management policy for managing the encryption key.
Returns null if `enable_kms_role` is false.
Ensure dependent modules verify this output before using it.
EOT
  value       = var.enable_kms_role ? aws_iam_policy.kms_management_policy["kms_policy"].arn : null
}

# --- CloudWatch Alarm ARN --- #
# Returns null if enable_key_monitoring = false.
# Note: Ensure dependent modules handle null values to avoid runtime errors.
output "kms_decrypt_alarm_arn" {
  description = <<EOT
The ARN of the CloudWatch Alarm for decrypt operations.
Returns null if `enable_key_monitoring` is false.
Ensure dependent modules verify this output before using it.
EOT
  value       = var.enable_key_monitoring ? aws_cloudwatch_metric_alarm.kms_decrypt_alarm[0].arn : null
}

# --- Notes --- #
# 1. The `kms_key_arn` is always available and represents the main encryption key ARN.
# 2. Outputs like `kms_management_role_arn` and `kms_management_policy_arn` are conditional.
#    - If `enable_kms_role` is false, these outputs will return `null`.
#    - Ensure that dependent modules verify these outputs before using them to avoid runtime errors.
# 3. Outputs are designed for integration with other modules, ensuring flexibility and scalability.
# 4. Consider grouping related outputs into maps in future improvements to reduce duplication.