# --- Application Load Balancer --- #
# This resource creates a public-facing Application Load Balancer (ALB) to handle incoming HTTP/HTTPS traffic.
# checkov:skip=CKV2_AWS_20: HTTPS redirect is disabled intentionally in test environment.
resource "aws_lb" "application" {
  name     = "${var.name_prefix}-alb" # ALB name
  internal = false                    # tfsec:ignore:aws-elb-alb-not-public

  # The ALB must be public since it is handling incoming traffic for a public WordPress website.
  # A private ALB is not suitable for this use case.
  load_balancer_type = "application"                  # Application Load Balancer type
  security_groups    = [aws_security_group.alb_sg.id] # Security Group for ALB
  subnets            = var.public_subnets             # ALB spans public subnets

  # Deletion protection to prevent accidental deletion
  enable_deletion_protection = var.alb_enable_deletion_protection

  # To enhance security, enable header dropping for ALB
  drop_invalid_header_fields = true

  # The amount of time (in seconds) that ALB will keep the connection open if no data is being transferred.
  idle_timeout = 60

  # The type of IP addresses used by ALB
  ip_address_type = "ipv4"

  # Access logging configuration for ALB logs
  # Ensure Access Logs are enabled only if logging is enabled AND the logging bucket is specified.
  dynamic "access_logs" {
    for_each = var.enable_alb_access_logs && var.alb_logs_bucket_name != null ? [1] : [] # Access logs enabled based on variable AND bucket name is not null

    content {
      bucket  = var.alb_logs_bucket_name   # S3 bucket for storing ALB logs
      prefix  = ""                         # Empty so that ALB uses the standard AWS path
      enabled = var.enable_alb_access_logs # Control logging via variable - although for_each already controls creation
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-${var.environment}"
  })
}

# --- Target Group for ALB --- #
# This resource defines a target group for the ALB to forward traffic to ASG instances
resource "aws_lb_target_group" "wordpress" {
  name     = "${var.name_prefix}-wordpress-tg" # Target group name
  port     = var.target_group_port             # Port for traffic (default: 80 for HTTP)
  protocol = "HTTP"                            # Protocol for traffic
  vpc_id   = var.vpc_id                        # VPC where the target group exists

  # Health check configuration for monitoring target instance health
  # Verify that the health check path and thresholds align with the application requirements.
  # Proper configuration ensures fast failure detection and prevents routing traffic to unhealthy instances.
  # Consider stricter criteria for critical applications:
  # - Lower `timeout` and `interval` values for faster detection of failures.
  # - Higher `healthy_threshold` to ensure stability before marking targets as healthy.
  # 
  # During WordPress installation:
  # - Higher unhealthy_threshold to be more tolerant of temporary failures
  # - Shorter interval for more frequent checks
  # - Quicker healthy_threshold to start serving traffic sooner
  health_check {
    path                = "/healthcheck.php" # Health check endpoint
    interval            = 60                 # Time (seconds) between health checks
    timeout             = 10                 # Time to wait for a response before failing
    healthy_threshold   = 2                  # Consecutive successes required to mark healthy
    unhealthy_threshold = 5                  # Higher threshold during installation phase
    matcher             = "200-299"          # Acceptable HTTP codes for successful health checks
  }

  # Additional attributes for the target group behavior
  deregistration_delay = 300 # 5 minutes delay before deregistering targets (increased for installation)
  slow_start           = 300 # Gradual traffic increase for new targets over 5 minutes

  # Stickiness Configuration
  # Ensures clients are routed to the same target for the duration of their session.
  # Useful for WordPress to maintain session consistency and avoid issues with login or caching.
  stickiness {
    enabled         = true        # Enable stickiness
    type            = "lb_cookie" # Use load balancer-managed cookies
    cookie_duration = 86400       # Duration of the cookie (1 day)
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-wordpress-tg-${var.environment}"
  })
}

# --- ALB Listener Configuration for HTTP --- #
# HTTP traffic is redirected to HTTPS only if enable_https_listener is set to true.
# tfsec:ignore:aws-elb-http-not-used
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.application.arn
  port              = 80

  # HTTPS is not used because there is no SSL certificate available.
  protocol = "HTTP"

  # Default action: Redirect HTTP traffic to HTTPS for secure communication (prevents sending sensitive data over HTTP).
  dynamic "default_action" {
    for_each = var.enable_https_listener ? [1] : []
    content {
      type = "redirect"
      redirect {
        protocol    = "HTTPS"
        port        = "443"
        status_code = "HTTP_301"
      }
    }
  }

  # Default action: Forward traffic to the target group
  dynamic "default_action" {
    for_each = !var.enable_https_listener ? [1] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.wordpress.arn
    }
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
#
# Key Features:
# - Access logs: Controlled by the `var.enable_alb_access_logs` variable.
# - Health checks monitor target availability and ensure stable traffic routing.
# - Secure traffic:
#   - HTTPS Listener ensures encrypted communication when enabled.
#   - HTTP requests are redirected to HTTPS when the HTTPS Listener is active.
#
# - Note: ALB communicates with targets (EC2 instances) over HTTP even if the client connects via HTTPS.
#   - TLS termination happens at ALB level for performance optimization.
#
# Recommendations:
# - Use valid SSL certificates for HTTPS.
# - Periodically review health check settings to align with application requirements.
# - Enable HTTPS Listener for environments requiring secure traffic.
# - Regularly monitor ALB logs and metrics for performance and security insights.