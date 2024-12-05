# --- Application Load Balancer --- #
# This resource creates an Application Load Balancer (ALB) to handle incoming HTTP traffic
resource "aws_lb" "application" {
  name               = "${var.name_prefix}-alb"       # ALB name
  internal           = false                          # ALB is public-facing
  load_balancer_type = "application"                  # Application Load Balancer type
  security_groups    = [aws_security_group.alb_sg.id] # Security Group for ALB
  subnets            = var.public_subnets             # ALB spans public subnets

  # Deletion protection to prevent accidental deletion
  enable_deletion_protection = false
  # Enable cross-zone load balancing for improved distribution
  enable_cross_zone_load_balancing = true
  # To enhance security, enable header dropping for ALB
  drop_invalid_header_fields = true

  # Access logging configuration for ALB logs
  access_logs {
    bucket  = var.logging_bucket             # S3 bucket for storing logs
    prefix  = "${var.name_prefix}/alb-logs/" # Separate ALB logs with a specific prefix
    enabled = true                           # Enable logging
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
    path                = "/" # Health check endpoint
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
# This resource creates an HTTP listener for ALB to route traffic to the target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.application.arn # ALB ARN
  port              = 80                     # Listener port for HTTP traffic
  protocol          = "HTTP"                 # Protocol for the listener

  # Default action: Forward traffic to the target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}

# --- Optional: HTTPS Listener (Disabled) --- #
# Uncomment the following resource for enabling HTTPS listener when a domain and SSL certificate are available
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.application.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = aws_acm_certificate.example.arn
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.wordpress.arn
#   }
# }
