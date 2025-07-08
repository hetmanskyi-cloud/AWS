# --- EFS Module Outputs --- #
# This file defines the outputs that this module makes available to other parts of the Terraform configuration.

# --- EFS File System Outputs --- #

output "efs_id" {
  description = "The ID of the EFS file system."
  value       = aws_efs_file_system.efs.id
}

output "efs_arn" {
  description = "The Amazon Resource Name (ARN) of the EFS file system."
  value       = aws_efs_file_system.efs.arn
}

output "efs_dns_name" {
  description = "The DNS name for the EFS file system, used for mounting."
  value       = aws_efs_file_system.efs.dns_name
}

# --- EFS Access Point Output --- #

output "efs_access_point_id" {
  description = "The ID of the EFS Access Point."
  value       = aws_efs_access_point.default.id
}

# --- Security Group Output --- #

output "efs_security_group_id" {
  description = "The ID of the security group created for the EFS mount targets."
  value       = aws_security_group.efs_sg.id
}

# --- Notes --- #
# 1. `efs_id`:
#    - The file system ID. It's required for the mount command.
#
# 2. `efs_access_point_id`:
#    - This is the most critical output for a secure setup. It will be passed to the user_data
#      script to ensure instances mount via the secure Access Point.
#
# 3. Usage:
#    - In the root module, you will access these values like so: `module.efs.efs_id`.
