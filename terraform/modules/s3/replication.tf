# --- S3 Replication Configuration --- #

# Local variable to check if any replication buckets are enabled
locals {
  replication_buckets_enabled = length([
    for key, value in var.replication_region_buckets : key
    if value.enabled
  ]) > 0
}

# --- IAM Role for Replication --- #
resource "aws_iam_role" "replication_role" {
  count = length([
    for value in var.default_region_buckets : value
    if value.enabled && value.replication
  ]) > 0 && local.replication_buckets_enabled ? 1 : 0

  name = "${var.name_prefix}-replication-role" # Role name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "s3.amazonaws.com" }, # S3 service principal
        Action    = "sts:AssumeRole"                  # AssumeRole action
      }
    ]
  })

  tags = {
    Name        = "${var.name_prefix}-replication-role"
    Environment = var.environment
  }
}

# --- IAM Policy for Replication --- #
resource "aws_iam_policy" "replication_policy" {
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value
    if value.enabled && value.replication && local.replication_buckets_enabled
  })

  name        = "${var.name_prefix}-replication-policy-${each.key}" # Policy name
  description = "IAM Policy for S3 Replication for ${each.key}"     # Policy description

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Statement: ReplicationRead (Source Bucket - Bucket Level Read Permissions)
      {
        Sid    = "ReplicationRead${replace(replace(each.key, "-", ""), "_", "")}"
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          aws_s3_bucket.default_region_buckets[each.key].arn
        ]
      },
      # Statement: ReplicationObjectRead (Source Bucket - Object Level Read Permissions)
      {
        Sid    = "ReplicationObjectRead${replace(replace(each.key, "-", ""), "_", "")}"
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging",
          "s3:GetObjectVersionForReplication"
        ]
        Resource = [
          "${aws_s3_bucket.default_region_buckets[each.key].arn}/*"
        ]
      },
      # Statement: ReplicationDestinationRead (Destination Bucket - Bucket Level Read Permissions)
      {
        Sid    = "ReplicationDestinationRead${replace(replace(each.key, "-", ""), "_", "")}"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          aws_s3_bucket.s3_replication_bucket[each.key].arn
        ]
      },
      # Statement: ReplicationWrite (Destination Bucket - Write Permissions)
      {
        Sid    = "ReplicationWrite${replace(replace(each.key, "-", ""), "_", "")}"
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "${aws_s3_bucket.s3_replication_bucket[each.key].arn}/*",
          aws_s3_bucket.s3_replication_bucket[each.key].arn
        ]
      },
      # Statement: KMSPermissions (KMS Key Permissions for Encryption)
      {
        Sid    = "KMSPermissions"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
          "kms:DescribeKey"
        ]
        Resource = compact([
          var.kms_key_arn,
          "${var.kms_key_arn}/*",
          var.kms_replica_key_arn != null ? var.kms_replica_key_arn : null,
          var.kms_replica_key_arn != null ? "${var.kms_replica_key_arn}/*" : null
        ])
      }
    ]
  })
}

# --- Attach Replication Policy to Role --- #
resource "aws_iam_role_policy_attachment" "replication_policy_attachment" {
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value
    if value.enabled && value.replication && local.replication_buckets_enabled
  })

  role       = try(aws_iam_role.replication_role[0].name, "")
  policy_arn = aws_iam_policy.replication_policy[each.key].arn
}

# --- S3 Bucket Replication Config --- #
resource "aws_s3_bucket_replication_configuration" "replication_config" {
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value
    if value.enabled && value.replication && local.replication_buckets_enabled
  })

  bucket = aws_s3_bucket.default_region_buckets[each.key].id
  role   = try(aws_iam_role.replication_role[0].arn, "")

  rule {
    id       = "ReplicationRule-${each.key}"
    status   = "Enabled"
    priority = 1

    filter {
      prefix = ""
    }

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    destination {
      bucket        = aws_s3_bucket.s3_replication_bucket[each.key].arn
      storage_class = "STANDARD"

      metrics {
        status = "Enabled"
      }

      encryption_configuration {
        # Using a replica KMS key for the replication region (best practice for key separation & regional compliance).
        # Fallback logic on KMS keys ensures dynamic replication configuration without failures when the replica key is not created.
        replica_kms_key_id = var.kms_replica_key_arn != null && var.kms_replica_key_arn != "" ? var.kms_replica_key_arn : var.kms_key_arn
      }
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }

  depends_on = [
    aws_s3_bucket.default_region_buckets,
    aws_s3_bucket.s3_replication_bucket,
    aws_s3_bucket_versioning.default_region_bucket_versioning,
    aws_s3_bucket_versioning.replication_region_bucket_versioning
  ]
}

# --- Notes --- #
# 1. IAM Role: Manages S3 cross-region replication permissions.
# 2. IAM Policy: Fine-grained access control for replication (attached to Role).
# 3. Replication Config: Applied only to default region buckets with replication enabled.
# 4. Security Best Practices: Dedicated IAM roles/policies, KMS encryption support.
# 5. Replication Scope Limitation:
#    - Replication is configured *only for SSE-KMS encrypted objects*.
#    - Objects encrypted with SSE-S3 or no encryption are *NOT* replicated.
#    - **If all objects replication is required, remove `source_selection_criteria` block or adjust configuration.
# 6. Source Object Requirement:
#    - Replication is configured ONLY for objects encrypted with SSE-KMS.
#    - Ensure 'aws_s3_bucket_server_side_encryption_configuration' enables SSE-KMS for source buckets.
#    - To replicate unencrypted or SSE-S3 objects, adjust or remove 'source_selection_criteria'.
# 7. Replica KMS Key:
#    - Recommended to specify 'kms_replica_key_arn' for compliance in the replication region.
#    - Fallback to source KMS key if not provided.