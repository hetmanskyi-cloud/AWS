# --- EFS File System Policy --- #
# This file defines the resource-based policy for the EFS file system to enforce security controls.

resource "aws_efs_file_system_policy" "efs_policy" {

  file_system_id = aws_efs_file_system.efs.id

  # This policy enforces two rules:
  # 1. (Allow) Permits read/write/mount operations ONLY through the specified Access Point.
  # 2. (Deny) Explicitly denies any connection that does not use TLS encryption.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      # Statement 1 (Allow): Permits client mount and write operations, but only if the
      # connection is made through the specific Access Point created for our application.
      # This effectively locks down the file system to a single, controlled entry point.
      {
        "Sid" : "AllowAppAccessViaAccessPoint",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite"
        ],
        "Resource" : aws_efs_file_system.efs.arn,
        "Condition" : {
          "StringEquals" : {
            "elasticfilesystem:AccessPointArn" : aws_efs_access_point.default.arn
          }
        }
      },
      # Statement 2 (Deny): A global security rule that explicitly denies any action
      # on the file system if the connection is not using TLS. This prevents all
      # unencrypted data transmission, protecting data in transit.
      {
        "Sid" : "EnforceInTransitEncryption",
        "Effect" : "Deny",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : "*",
        "Resource" : aws_efs_file_system.efs.arn,
        "Condition" : {
          "Bool" : {
            "aws:SecureTransport" : "false"
          }
        }
      }
    ]
  })

  depends_on = [
    aws_efs_file_system.efs,
    aws_efs_access_point.default
  ]
}

# --- Notes --- #
# 1. **Purpose**:
#    - The `aws_efs_file_system_policy` resource attaches a policy directly to the EFS file system,
#      similar to an S3 bucket policy.
#
# 2. **Dual-Layer Security**:
#    - This policy implements a robust, two-layer security model:
#    - a) **Access Control (Allow)**: The first statement permits mount and write operations, but only
#         if the connection is made through the specific Access Point created for our application. This
#         acts as the primary authorization mechanism.
#    - b) **Encryption Enforcement (Deny)**: The second statement is a blanket rule that denies any
#         action if the connection is not encrypted with TLS. This protects all data in transit.
#
# 3. **Mandatory Policy**:
#    - The creation of this policy is a mandatory and integral part of this module. It is not
#      optional, ensuring a secure-by-default architecture for all deployments.
