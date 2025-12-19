# --- Security Group for the ALB --- #
# This security group defines the base configuration for the ALB.
# It controls inbound traffic from the public internet and outbound traffic to targets.
resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.name_prefix}-alb-sg-${var.environment}" # Security group name prefixed with the environment name.
  vpc_id      = var.vpc_id                                     # VPC where the ALB resides.
  description = "Security group for ALB handling inbound and outbound traffic"

  # Ensures a new Security Group is created before the old one is destroyed to avoid downtime.
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg-${var.environment}"
  })
}

# --- Data Source for AWS Managed Prefix List --- #

# Fetches the AWS-managed prefix list for CloudFront IPs.
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# --- Conditional Ingress Rules --- #
# These rules are created based on the boolean value of var.alb_access_cloudfront_mode.

# --- Rule for "open" mode (if variable is false) --- #

# --- Ingress Rule for HTTP (CloudFront mode disabled) --- #
# HTTP is enabled to allow redirecting users from HTTP to HTTPS.
# HTTPS is conditionally enabled based on 'enable_https_listener' variable and SSL certificate configuration.

# Allow HTTP traffic from anywhere if alb_access_cloudfront_mode is false (CloudFront mode disabled).
resource "aws_security_group_rule" "ingress_alb_http_open" {
  count = var.alb_access_cloudfront_mode ? 0 : 1

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  # checkov:skip=CKV_AWS_260:This rule is intentionally open to allow HTTP traffic for redirection to HTTPS. It is disabled when CloudFront is the only entry point.
  #tfsec:ignore:aws-vpc-no-public-ingress-sgr
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow HTTP traffic for redirecting to HTTPS or serving plain HTTP if HTTPS is disabled"
}

# --- Ingress Rule for HTTPS (CloudFront mode disabled) --- #
resource "aws_security_group_rule" "ingress_alb_https_open" {
  # Create this rule only if the variable is false AND https is enabled.
  count = !var.alb_access_cloudfront_mode && var.enable_https_listener ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS traffic from anywhere"

  # Note: 0.0.0.0/0 is required to allow public HTTPS access.
  # Ensure the SSL certificate provided via `certificate_arn` is valid and properly configured and tested in production.
  # The HTTPS listener depends on a valid SSL certificate to function correctly.
  # If SSL certificate is missing, var.enable_https_listener variable should be set to false
}

# --- Rules for "CloudFront-Only" Mode (alb_access_cloudfront_mode = true) --- #
# This set of rules creates the most secure configuration by locking down the ALB
# to only accept traffic from CloudFront IPs and internal health checks from within the VPC.

# --- Rule 1.1: Allow HTTP Traffic from CloudFront --- #
# Allows end-user traffic proxied through CloudFront to reach the ALB on port 80.
resource "aws_security_group_rule" "ingress_http_cloudfront" {
  count = var.alb_access_cloudfront_mode ? 1 : 0

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  description       = "Allow HTTP traffic from the AWS CloudFront managed prefix list"
}

# --- Rule 1.2: Allow HTTP Health Checks from within the VPC --- #
# CRITICAL: This rule allows the ALB's own health checker nodes (which are inside the VPC
# and NOT part of the CloudFront prefix list) to reach the targets.
resource "aws_security_group_rule" "ingress_http_healthcheck_internal" {
  count = var.alb_access_cloudfront_mode ? 1 : 0

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = [var.vpc_cidr_block]
  description       = "Allow HTTP from within the VPC for ALB health checks"
}

# --- Rule 1.3: Allow HTTPS Traffic from CloudFront --- #
# Allows end-user HTTPS traffic from CloudFront if the HTTPS listener is enabled.
resource "aws_security_group_rule" "ingress_https_cloudfront" {
  count = var.alb_access_cloudfront_mode && var.enable_https_listener ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  description       = "Allow HTTPS traffic from the AWS CloudFront managed prefix list"
}

# --- Rule 1.4: Allow HTTPS Health Checks from within the VPC --- #
# Mirrors the HTTP health check rule for the HTTPS port. This is required if the ALB
# is configured to perform health checks over HTTPS.
resource "aws_security_group_rule" "ingress_https_healthcheck_internal_https" {
  count = var.alb_access_cloudfront_mode && var.enable_https_listener ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = [var.vpc_cidr_block]
  description       = "Allow HTTPS from within the VPC for ALB health checks"
}

# --- Egress Rule for ALB --- #

# Allows outbound traffic from the ALB specifically to the ASG instances on the target port.
# This follows the principle of least privilege, hardening the security posture.
resource "aws_security_group_rule" "alb_egress_all" {

  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  # Direct traffic only to Security Group ASG module instances
  source_security_group_id = var.asg_security_group_id
  description              = "Allow outbound traffic from ALB to ASG instances"
}

# --- Notes --- #
# 1. Conditional Ingress Logic:
#    - This security group implements dynamic ingress rules controlled by the 'alb_access_cloudfront_mode' variable.
#    - This provides flexibility to run the ALB in two distinct modes, suitable for different environments.
#
# 2. Access Modes:
#    - 'alb_access_cloudfront_mode = false' (Open Mode): Allows public ingress traffic from anywhere (0.0.0.0/0).
#      This mode is suitable for development or testing environments where direct access to the ALB is required.
#    - 'alb_access_cloudfront_mode = true' (CloudFront Mode): The recommended setting for production. It restricts
#      all ingress traffic to only the IPs listed in the AWS Managed Prefix List for CloudFront. This ensures
#      that no traffic can bypass the CloudFront distribution and hit the ALB directly.
#
# 3. AWS Managed Prefix List:
#    - The 'cloudfront' mode relies on the "com.amazonaws.global.cloudfront.origin-facing" managed prefix list.
#    - This list is automatically maintained by AWS, guaranteeing that the rules are always up-to-date with the
#      latest CloudFront IP ranges without any manual intervention.
#
# 4. Egress Architecture (Principle of Least Privilege):
#    - The egress rule strictly limits outbound traffic from the ALB exclusively to the security group of the
#      backend Auto Scaling Group (ASG) on the application's listening port (e.g., port 80).
#    - This configuration implements the "TLS Termination at the Load Balancer" pattern, which is a standard
#      and highly recommended architecture for web applications. The key benefits are:
#      * Centralized Certificate Management: SSL/TLS certificates are managed solely on the ALB, eliminating
#        the need to deploy and rotate certificates on each individual application server.
#      * Improved Backend Performance: Application servers are offloaded from the computational overhead of
#        TLS encryption/decryption, freeing up CPU cycles for their primary tasks.
#      * Secure by Design: Communication between the ALB and the backend instances occurs within the secure
#        and private environment of the VPC, isolated from public internet traffic.
#
# 5. Defense-in-Depth:
#    - This security group acts as the network-level (L4) defense for the ALB.
#    - It works in tandem with the application-level (L7) AWS WAF, which validates the secret header from
#      CloudFront, to create a robust, multi-layered security posture.
