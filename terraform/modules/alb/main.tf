# --- Application Load Balancer --- #
# This resource creates a public-facing Application Load Balancer (ALB) to handle incoming HTTP/HTTPS traffic.
resource "aws_lb" "application" {
  name               = "${var.name_prefix}-alb"       # ALB name
  internal           = false                          # ALB is public-facing
  load_balancer_type = "application"                  # Application Load Balancer type
  security_groups    = [aws_security_group.alb_sg.id] # Security Group for ALB
  subnets            = var.public_subnets             # ALB spans public subnets

  # Deletion protection to prevent accidental deletion
  enable_deletion_protection = var.alb_enable_deletion_protection
  # Enable cross-zone load balancing for improved distribution
  enable_cross_zone_load_balancing = true
  # To enhance security, enable header dropping for ALB
  drop_invalid_header_fields = true
  # The amount of time (in seconds) that ALB will keep the connection open if no data is being transferred.
  idle_timeout = 60
  # The type of IP addresses used by ALB
  ip_address_type = "ipv4"

  # --- Access logging configuration for ALB logs --- #
  # Ensure Access Logs are enabled only if the logging bucket is specified.
  dynamic "access_logs" {
    for_each = var.logging_bucket != null ? [1] : []

    content {
      bucket  = var.logging_bucket             # S3 bucket for storing logs
      prefix  = "${var.name_prefix}/alb-logs/" # Separate ALB logs with a specific prefix
      enabled = var.enable_alb_access_logs     # Control logging via variable
    }
  }

  tags = {
    Name        = "${var.name_prefix}-alb"
    Environment = var.environment
  }
}

# --- Target Group for ALB --- #
# This resource defines a target group for the ALB to forward traffic to ASG instances
resource "aws_lb_target_group" "wordpress" {
  name     = "${var.name_prefix}-wordpress-tg" # Target group name
  port     = var.target_group_port             # Port for traffic (default: 80 for HTTP)
  protocol = "HTTP"                            # Protocol for traffic
  vpc_id   = var.vpc_id                        # VPC where the target group exists

  # --- Health check configuration for monitoring target instance health --- #
  # Verify that the health check path and thresholds align with the application requirements.
  # Consider stricter criteria for critical applications:
  # - Lower `timeout` and `interval` values for faster detection of failures.
  # - Higher `healthy_threshold` to ensure stability before marking targets as healthy.
  health_check {
    path                = "/"       # Health check endpoint (default path, can be customized for app-specific needs).
    interval            = 30        # Time (seconds) between health checks
    timeout             = 5         # Time to wait for a response before failing
    healthy_threshold   = 3         # Consecutive successes required to mark healthy
    unhealthy_threshold = 3         # Consecutive failures required to mark unhealthy
    matcher             = "200-299" # Acceptable HTTP codes for successful health checks
  }

  # Additional attributes for the target group behavior
  deregistration_delay = 300 # 300 seconds delay before deregistering targets
  slow_start           = 30  # Gradual traffic increase for new targets over 30 seconds

  # --- Stickiness Configuration --- #
  # Ensures clients are routed to the same target for the duration of their session.
  stickiness {
    enabled         = true        # Enable stickiness
    type            = "lb_cookie" # Use load balancer-managed cookies
    cookie_duration = 86400       # Duration of the cookie (1 day)
  }

  # --- Tags --- #
  tags = {
    Name        = "${var.name_prefix}-wordpress-tg" # Name tag for resource identification
    Environment = var.environment                   # Environment tag for organization
  }
}

# --- ALB Listener Configuration for HTTP --- #
# HTTP traffic is redirected to HTTPS only if enable_https_listener is set to true.
resource "aws_lb_listener" "http" {
  count = 1 # Always create an HTTP listener for handling traffic.

  load_balancer_arn = aws_lb.application.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.enable_https_listener ? "redirect" : "forward"

    # Redirect HTTP to HTTPS if HTTPS listener is active.
    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }

    # Forward traffic to the target group if HTTPS listener is not active.
    target_group_arn = var.enable_https_listener ? null : aws_lb_target_group.wordpress.arn
  }
}

# --- HTTPS Listener Configuration --- #
# HTTPS Listener creation is controlled by a count variable.
# Ensure the `certificate_arn` variable is validated and non-empty if `enable_https_listener` is `true`.
# Missing or invalid certificates will cause Terraform to fail during creation.
# Add explicit checks for `certificate_arn` in `variables.tf` to prevent deployment issues.
resource "aws_lb_listener" "https" {
  count             = var.enable_https_listener ? 1 : 0 # Controlled by a variable to determine creation.
  load_balancer_arn = aws_lb.application.arn
  port              = 443                                 # Listener port for HTTPS traffic
  protocol          = "HTTPS"                             # Protocol for the listener
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01" # SSL policy
  certificate_arn   = var.certificate_arn                 # SSL Certificate ARN (required for HTTPS)

  # Default action: Forward traffic to the target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}

# --- Notes --- #

# General Logic:
# - HTTP Listener: Always created to handle traffic on port 80.
#   - If `enable_https_listener` is true, HTTP traffic is redirected to HTTPS on port 443.
#   - If `enable_https_listener` is false, HTTP traffic is forwarded to the Target Group.
# - HTTPS Listener: Created only when `enable_https_listener` is set to true.
#   - SSL Certificate ARN must be provided when enabling the HTTPS Listener.

# Key Features:
# - Cross-zone load balancing ensures even traffic distribution across AZs.
# - Access logs: Controlled by the `var.enable_alb_access_logs` variable.
# - Health checks monitor target availability and ensure stable traffic routing.
# - Secure traffic:
#   - HTTPS Listener ensures encrypted communication when enabled.
#   - HTTP requests are redirected to HTTPS when the HTTPS Listener is active.

# Recommendations:
# - Use valid SSL certificates for HTTPS.
# - Periodically review health check settings to align with application requirements.
# - Enable HTTPS Listener for environments requiring secure traffic.
# - Regularly monitor ALB logs and metrics for performance and security insights.