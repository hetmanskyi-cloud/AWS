# --- S3 Replication Configuration --- #

# --- IAM Role for S3 Replication ---
resource "aws_iam_role" "replication_role" {
  count = length([
    for value in var.default_region_buckets : value
    if value.enabled && value.replication
  ]) > 0 && local.replication_buckets_enabled ? 1 : 0

  name = "${var.name_prefix}-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.name_prefix}-replication-role"
    Environment = var.environment
  }
}

# --- IAM Policy for S3 Replication --- #
resource "aws_iam_policy" "replication_policy" {
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value
    if value.enabled && value.replication && local.replication_buckets_enabled
  })

  name        = "${var.name_prefix}-replication-policy-${each.key}"
  description = "IAM Policy for S3 Replication for ${each.key}"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Read permissions for source buckets
      {
        Sid    = "ReplicationRead${replace(replace(each.key, "-", ""), "_", "")}",
        Effect = "Allow",
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.default_region_buckets[each.key].arn
        ]
      },
      # Read permissions for object versions
      {
        Sid    = "ReplicationObjectRead${replace(replace(each.key, "-", ""), "_", "")}",
        Effect = "Allow",
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ],
        Resource = [
          "${aws_s3_bucket.default_region_buckets[each.key].arn}/*"
        ]
      },
      # Write permissions for replication destination
      {
        Sid    = "ReplicationWrite${replace(replace(each.key, "-", ""), "_", "")}",
        Effect = "Allow",
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:PutObject"
        ],
        Resource = [
          "${aws_s3_bucket.s3_replication_bucket[keys(var.replication_region_buckets)[0]].arn}/*",
          aws_s3_bucket.s3_replication_bucket[keys(var.replication_region_buckets)[0]].arn,
        ]
      },
      # KMS Permissions
      {
        Sid    = "KMSPermissions",
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
      }
    ]
  })
}

# --- Attach IAM Policy to Replication Role --- #
resource "aws_iam_role_policy_attachment" "replication_policy_attachment" {
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value
    if value.enabled && value.replication && local.replication_buckets_enabled
  })

  role       = aws_iam_role.replication_role[0].name
  policy_arn = aws_iam_policy.replication_policy[each.key].arn
}

# --- S3 Bucket Replication Configuration --- #
resource "aws_s3_bucket_replication_configuration" "replication_config" {
  for_each = tomap({
    for key, value in var.default_region_buckets : key => value
    if value.enabled && value.replication && local.replication_buckets_enabled
  })

  bucket = aws_s3_bucket.default_region_buckets[each.key].id
  role   = aws_iam_role.replication_role[0].arn

  rule {
    id       = "ReplicationRule-${each.key}"
    status   = "Enabled"
    priority = 1

    filter {}

    destination {
      bucket        = aws_s3_bucket.s3_replication_bucket[keys(var.replication_region_buckets)[0]].arn
      storage_class = "STANDARD"
    }

    delete_marker_replication {
      status = "Disabled"
    }
  }

  depends_on = [aws_s3_bucket.default_region_buckets, aws_s3_bucket.s3_replication_bucket]
}

# --- Notes --- #
# 1. IAM Role (`aws_iam_role "replication_role"`) manages permissions for S3 cross-region replication.
# 2. IAM Policy (`aws_iam_policy "replication_policy"`) attached to the IAM Role defines fine-grained access control for replication operations.
# 3. Replication configuration (`aws_s3_bucket_replication_configuration "replication_config"`) is applied only for default region buckets where replication is explicitly enabled.
# 4. Implements security best practices for S3 cross-region replication, including dedicated IAM roles and policies, and supports KMS encryption for replicated objects.