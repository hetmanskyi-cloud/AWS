# Prefix for naming resources, used for easy identification.
variable "name_prefix" {
  description = "Prefix for naming resources for easier organization"
  type        = string
}

# Environment label (e.g., dev, staging, prod) for tagging and organizing resources.
variable "environment" {
  description = "Environment label to organize resources (e.g., dev, staging, prod)"
  type        = string
}

# Threshold for high request count alarm
variable "alb_request_count_threshold" {
  description = "Threshold for high request count on ALB"
  type        = number
  default     = 1000
}

# Threshold for 5XX error alarm
variable "alb_5xx_threshold" {
  description = "Threshold for 5XX errors on ALB"
  type        = number
  default     = 50
}

# Name of the ALB
variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
}

# ARN of the SNS Topic for CloudWatch alarms
variable "sns_topic_arn" {
  description = "ARN of the SNS Topic for sending CloudWatch alarm notifications"
  type        = string
}
