# --- Application Load Balancer --- #
# This resource creates a public-facing Application Load Balancer (ALB) to handle incoming HTTP traffic
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

  # Access logging configuration for ALB logs
  access_logs {
    bucket  = var.logging_bucket             # S3 bucket for storing logs
    prefix  = "${var.name_prefix}/alb-logs/" # Separate ALB logs with a specific prefix
    enabled = var.environment != "dev"       # Enable logging for stage and prod
  }

  tags = {
    Name        = "${var.name_prefix}-alb"
    Environment = var.environment
  }
}

# --- Target Group for ALB --- #
# This resource defines a target group for the ALB to forward traffic to EC2 instances
resource "aws_lb_target_group" "wordpress" {
  name     = "${var.name_prefix}-wordpress-tg" # Target group name
  port     = var.target_group_port             # Port for traffic (default: 80 for HTTP)
  protocol = "HTTP"                            # Protocol for traffic
  vpc_id   = var.vpc_id                        # VPC where the target group exists

  # Health check configuration for monitoring target instance health
  health_check {
    # Health check path:
    # - Use "/" for basic root-level health checks.
    # - Use "/healthz" for custom application-specific checks (common in microservices).
    path                = "/" # Health check endpoint (default path, can be customized for app-specific needs).
    interval            = 30  # Time (seconds) between health checks
    timeout             = 5   # Time to wait for a response before failing
    healthy_threshold   = 3   # Consecutive successes required to mark healthy
    unhealthy_threshold = 3   # Consecutive failures required to mark unhealthy
  }

  tags = {
    Name        = "${var.name_prefix}-wordpress-tg"
    Environment = var.environment
  }
}

# --- ALB Listener for HTTP --- #
# Redirects HTTP traffic to HTTPS in stage and prod. Routes traffic in dev.
resource "aws_lb_listener" "http" {
  count = 1 # Always create an HTTP listener for handling traffic

  load_balancer_arn = aws_lb.application.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    # Redirect HTTP to HTTPS in stage and prod
    type = var.environment == "dev" ? "forward" : "redirect"

    # Forward traffic to the target group in dev
    target_group_arn = var.environment == "dev" ? aws_lb_target_group.wordpress.arn : null

    # Redirect HTTP to HTTPS in stage and prod
    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}

# --- HTTPS Listener --- #
# HTTPS Listener is created only for stage and prod.
resource "aws_lb_listener" "https" {
  count             = var.environment != "dev" ? 1 : 0
  load_balancer_arn = aws_lb.application.arn
  port              = 443                         # Listener port for HTTPS traffic
  protocol          = "HTTPS"                     # Protocol for the listener
  ssl_policy        = "ELBSecurityPolicy-2016-08" # SSL policy
  certificate_arn   = var.certificate_arn         # SSL Certificate ARN (expected for stage/prod)

  # Default action: Forward traffic to the target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}

# --- Notes --- #

# Environment-Specific Logic:
# - ALB and Target Group are created for all environments (dev, stage, prod).
# - HTTP Listener:
#   - In dev: Routes traffic to the target group for testing.
#   - In stage and prod: Redirects HTTP traffic to HTTPS for secure communication.
# - HTTPS Listener is enabled in stage and prod to ensure secure and encrypted communication.
# - Access logs:
#   - Enabled only in stage and prod for compliance and analysis.
#   - Stored in a centralized S3 logging bucket with identifiable prefixes.
# - Deletion protection is enabled in prod to prevent accidental resource deletion.

# Health Checks:
# - Default path is root ("/"), suitable for most applications.
# - Use "/healthz" for more specific health checks (e.g., for microservices or containerized apps).
# - Conservative thresholds (e.g., interval, timeout) ensure accurate monitoring.

# Recommendations:
# - Always ensure the SSL certificate ARN is valid in stage and prod environments.
# - Regularly audit health check settings to align with application changes.
# - Periodically verify access logs for unexpected traffic patterns or anomalies.

# General Security:
# - Cross-zone load balancing is enabled to distribute traffic evenly across AZs.
# - Invalid header fields are dropped to enhance security and reduce attack vectors.