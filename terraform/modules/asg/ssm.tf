# --- AWS Systems Manager (SSM) Integration --- #
# This file defines the IAM policy attachment required to enable secure, shell-level access to EC2 instances
# via AWS Systems Manager (SSM) Session Manager. By attaching the AmazonSSMManagedInstanceCore policy,
# instances can communicate with the SSM service, allowing for management without the need for SSH access,
# bastion hosts, or open inbound ports in security groups.

# --- SSM Access Policy Attachment --- #
# Attaches the AWS managed policy `AmazonSSMManagedInstanceCore` to the IAM role used by the ASG instances.
# This policy grants the instance all necessary permissions to register with the SSM service and
# allow connections via Session Manager.
resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.asg_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# --- Notes --- #
# 1. **Primary Access Method**:
#    - SSM Session Manager is the **exclusive** method for administrative access to instances in this module.
#    - This approach entirely replaces traditional SSH, enhancing the security posture of the infrastructure.
#
# 2. **Security Benefits**:
#    - **No Open Ports**: Does not require inbound port 22 (or any other port) to be open to the internet.
#    - **Centralized IAM Control**: Access is controlled through IAM users, groups, and policies, not SSH keys.
#    - **Auditing**: All sessions and commands can be logged to CloudWatch Logs or S3 for a complete audit trail.
#
# 3. **Prerequisites**:
#    - **SSM Agent**: The EC2 instances launched by the ASG must have the SSM Agent installed and running. Most modern Amazon Linux 2 and Ubuntu AMIs include it by default.
#    - **Network Connectivity**: Instances must be able to communicate with the SSM service endpoints on port 443. In this architecture, this is achieved via the NAT Gateway in the VPC. For enhanced security, VPC Interface Endpoints for SSM could be used instead.
#
# 4. **Dependencies**:
#    - This resource depends on the `aws_iam_role.asg_role` defined in `iam.tf`. Terraform automatically handles this dependency.
