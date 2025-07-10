# --- EFS Main Resources --- #
# This file defines the core resources for the EFS module, including the file system
# and its mount targets within the specified subnets.

# --- Terraform and Provider Requirements --- #
terraform {
  required_version = "~> 1.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --- EFS File System Resource --- #
resource "aws_efs_file_system" "efs" {
  encrypted  = var.efs_encrypted
  kms_key_id = var.efs_encrypted ? var.kms_key_arn : null # tflint-ignore: aws_efs_file_system_invalid_kms_key_id

  performance_mode = var.performance_mode
  throughput_mode  = var.throughput_mode
  provisioned_throughput_in_mibps = (
    var.throughput_mode == "provisioned" ? var.provisioned_throughput_in_mibps : null
  )

  dynamic "lifecycle_policy" {
    for_each = var.enable_efs_lifecycle_policy ? [1] : []
    content {
      transition_to_ia = var.transition_to_ia
    }
  }

  lifecycle {
    prevent_destroy = false # In prod MUST be true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-efs-${var.environment}"
  })
}

# --- EFS Mount Target Resources --- #
# Creates a mount target in each of the specified subnets.
# Using for_each ensures that one mount target is created per subnet ID provided in the variable,
# which is essential for high availability across multiple Availability Zones.
resource "aws_efs_mount_target" "efs_mount_target" {
  for_each = var.subnet_ids_map

  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_sg.id]

  depends_on = [
    aws_efs_file_system.efs,
    aws_security_group.efs_sg
  ]
}

# --- Notes --- #
# 1. **File System (`aws_efs_file_system`)**:
#    - This is the central resource representing the shared file system.
#    - Encryption is enabled by default and uses the KMS key ARN provided.
#    - The `lifecycle_policy` block is created dynamically based on the `enable_lifecycle_policy` variable.
#      This policy helps save costs by moving inactive files to a cheaper storage tier.
#
# 2. **Mount Targets (`aws_efs_mount_target`)**:
#    - These resources act as network interfaces (ENIs) for the EFS file system within your VPC.
#    - The `for_each` loop is crucial here; it iterates over the list of `subnet_ids` and creates one
#      mount target in each, making the file system accessible across multiple Availability Zones.
#    - Each mount target is associated with the dedicated EFS security group to control access.
#
# 3. **Dependencies**:
#    - The mount targets explicitly depend on the file system and its security group to ensure
#      correct creation order during `terraform apply`.
