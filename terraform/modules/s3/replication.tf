# --- S3 Replication Configuration --- #

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
  ]) > 0 && local.replication_buckets_enabled ? 1 : 0 # Conditional role creation

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
    Name        = "${var.name_prefix}-replication-role" # Name tag
    Environment = var.environment                       # Environment tag
  }
}

# --- IAM Policy for Replication --- #
resource "aws_iam_policy" "replication_policy" {
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value
    if value.enabled && value.replication && local.replication_buckets_enabled # Conditional policy creation
  })

  name        = "${var.name_prefix}-replication-policy-${each.key}" # Policy name
  description = "IAM Policy for S3 Replication for ${each.key}"     # Policy description

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "ReplicationRead${replace(replace(each.key, "-", ""), "_", "")}" # Sid: ReplicationRead
        Effect = "Allow"                                                          # Effect: Allow
        Action = [                                                                # Actions:
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = [ # Resources: source bucket ARN
          aws_s3_bucket.default_region_buckets[each.key].arn
        ]
      },
      {
        Sid    = "ReplicationObjectRead${replace(replace(each.key, "-", ""), "_", "")}" # Sid: ReplicationObjectRead
        Effect = "Allow"                                                                # Effect: Allow
        Action = [                                                                      # Actions:
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = [ # Resources: source bucket ARN + objects
          "${aws_s3_bucket.default_region_buckets[each.key].arn}/*"
        ]
      },
      {
        Sid    = "ReplicationWrite${replace(replace(each.key, "-", ""), "_", "")}" # Sid: ReplicationWrite
        Effect = "Allow"                                                           # Effect: Allow
        Action = [                                                                 # Actions:
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:PutObject"
        ]
        Resource = [ # Resources: dest bucket ARN + objects
          "${aws_s3_bucket.s3_replication_bucket[keys(var.replication_region_buckets)[0]].arn}/*",
          aws_s3_bucket.s3_replication_bucket[keys(var.replication_region_buckets)[0]].arn,
        ]
      },
      {
        Sid    = "KMSPermissions" # Sid: KMSPermissions
        Effect = "Allow"          # Effect: Allow
        Action = [                # KMS Actions:
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
      }
    ]
  })
}

# --- Attach Replication Policy to Role --- #
resource "aws_iam_role_policy_attachment" "replication_policy_attachment" {
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value
    if value.enabled && value.replication && local.replication_buckets_enabled # Conditional attachment
  })

  role       = aws_iam_role.replication_role[0].name           # Replication role name
  policy_arn = aws_iam_policy.replication_policy[each.key].arn # Replication policy ARN
}

# --- S3 Bucket Replication Config --- #
resource "aws_s3_bucket_replication_configuration" "replication_config" {
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value
    if value.enabled && value.replication && local.replication_buckets_enabled # Conditional replication config
  })

  bucket = aws_s3_bucket.default_region_buckets[each.key].id # Source bucket
  role   = aws_iam_role.replication_role[0].arn              # Replication role ARN

  rule {
    id       = "ReplicationRule-${each.key}" # Rule ID
    status   = "Enabled"                     # Rule status: Enabled
    priority = 1                             # Priority: 1

    filter {} # Default filter (all objects)

    destination {
      bucket        = aws_s3_bucket.s3_replication_bucket[keys(var.replication_region_buckets)[0]].arn # Destination bucket ARN
      storage_class = "STANDARD"                                                                       # Storage class: STANDARD
    }

    delete_marker_replication {
      status = "Disabled" # Delete marker replication: Disabled
    }
  }

  depends_on = [aws_s3_bucket.default_region_buckets, aws_s3_bucket.s3_replication_bucket] # Depends on buckets
}

# --- Module Notes --- #
# General notes for S3 replication configuration.

# 1. IAM Role: Manages S3 cross-region replication permissions.
# 2. IAM Policy: Fine-grained access control for replication (attached to Role).
# 3. Replication Config: Applied only to default region buckets with replication enabled.
# 4. Security Best Practices: Dedicated IAM roles/policies, KMS encryption support.