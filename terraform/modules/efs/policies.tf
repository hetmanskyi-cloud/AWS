# --- EFS File System Policy --- #
# This file defines the resource-based policy for the EFS file system to enforce security controls.

resource "aws_efs_file_system_policy" "efs_policy" {
  count = var.enable_efs_policy ? 1 : 0

  file_system_id = aws_efs_file_system.efs.id

  # This policy enforces that all clients connecting to the EFS must use TLS encryption.
  # It denies any mount attempts where the connection is not secure.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "EnforceInTransitEncryption",
        "Effect" : "Deny",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : [
          "elasticfilesystem:ClientMount"
        ],
        "Condition" : {
          "Bool" : {
            "aws:SecureTransport" : "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_efs_file_system.efs]
}

# --- Notes --- #
# 1. **Purpose**:
#    - The `aws_efs_file_system_policy` resource attaches a policy directly to the EFS file system,
#      similar to an S3 bucket policy.
#
# 2. **Security**:
#    - The default policy provided here is a security best practice. It explicitly denies any client
#      from mounting the file system if they are not using TLS (in-transit encryption).
#    - This protects your data from being intercepted as it travels over the network between your
#      EC2 instances and the EFS mount targets.
#      AWS recommendation: https://docs.aws.amazon.com/efs/latest/ug/encryption-in-transit.html
#
# 3. **Control**:
#    - The creation of this policy is controlled by the `var.enable_efs_policy` variable, which
#      is set to `true` by default to encourage a secure-by-default configuration.
