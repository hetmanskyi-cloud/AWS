# --- IAM Role and Policy for S3 Replication --- #
# Defines IAM resources required for cross-region replication.

resource "aws_iam_role" "replication_role" {
  count = can(var.buckets["replication"].enabled && var.buckets["replication"].replication) ? 1 : 0

  name = "${var.name_prefix}-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.name_prefix}-replication-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "replication_policy" {
  count = can(var.buckets["replication"].enabled && var.buckets["replication"].replication) ? 1 : 0

  name = "${var.name_prefix}-replication-policy"
  role = aws_iam_role.replication_role[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ],
        Resource = [
          for key, value in var.buckets : aws_s3_bucket.buckets[key].arn if value.enabled && lookup(value, "replication", false)
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ],
        Resource = [
          for key, value in var.buckets : "${aws_s3_bucket.buckets[key].arn}/*" if value.enabled && lookup(value, "replication", false)
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ],
        Resource = [
          for key, value in var.buckets : aws_s3_bucket.buckets[key].arn if value.enabled && lookup(value, "replication", false) || (key == "replication" && var.buckets["replication"] != null && var.buckets["replication"].enabled)
        ]
      },
      {
        Effect   = "Allow",
        Action   = "s3:PutObject",
        Resource = "${aws_s3_bucket.buckets["replication"].arn}/*"
      }
    ]
  })
}

# --- Notes --- #
# 1. IAM role and policy for S3 cross-region replication.
# 2. Created dynamically based on 'replication' settings in terraform.tfvars.
# 3. Grants necessary permissions for replication.
# 4. Ensure source and destination buckets exist and are configured before enabling replication.