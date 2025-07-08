# --- EFS Security Group Configuration --- #
# This file defines the Security Group for EFS mount targets, allowing access from application instances.

# --- Security Group for EFS Mount Targets --- #
resource "aws_security_group" "efs_sg" {
  name_prefix = "${var.name_prefix}-efs-sg-${var.environment}"
  description = "Security Group for EFS mount targets, allows inbound NFS traffic."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-efs-sg-${var.environment}"
  })
}

# --- Ingress Rule: Allow NFS from ASG Instances --- #
# This is the primary rule that allows the application (WordPress) instances
# to connect to the EFS file system via the NFS protocol.
resource "aws_security_group_rule" "allow_nfs_inbound" {
  type                     = "ingress"
  from_port                = 2049 # NFS port
  to_port                  = 2049 # NFS port
  protocol                 = "tcp"
  source_security_group_id = var.asg_security_group_id # CRITICAL: Allows traffic only from the ASG security group
  security_group_id        = aws_security_group.efs_sg.id
  description              = "Allow inbound NFS (TCP port 2049) from ASG instances"
}

# --- Egress Rules (Outbound Traffic) --- #
# No explicit egress rules are defined for this security group.
# Security Groups in AWS are stateful. This means that if an inbound connection is allowed (like the NFS connection above),
# the return traffic for that connection is automatically permitted, regardless of egress rules.
# Since EFS mount targets only respond to connections and do not initiate their own outbound traffic,
# omitting an egress rule enforces a "deny all" policy for initiated outbound connections, which is the most secure posture.

# --- Notes --- #
# 1. **Principle of Least Privilege**:
#    - The ingress rule is highly specific. It only allows traffic on port 2049 (NFS)
#      and only from the security group attached to your application instances (`var.asg_security_group_id`).
#    - This prevents any other resource in the VPC from accessing the file system.
#
# 2. **Stateful Egress**:
#    - Because Security Groups are stateful, return traffic for the allowed NFS connection is automatically permitted.
#    - By not defining any egress rules, we ensure the highest level of security, as no outbound connections can be initiated
#      from the EFS mount target's network interface.
#
# 3. **Dependencies**:
#    - This configuration depends on `var.vpc_id` (from the VPC module) and `var.asg_security_group_id`
#      (from the ASG module) being passed correctly from the root module.
