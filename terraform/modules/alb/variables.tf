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

# --- Variables for the ALB Module --- #

variable "public_subnets" {
  description = "List of public subnet IDs for ALB placement"
  type        = list(string)
}

variable "logging_bucket" {
  description = "S3 bucket name for storing ALB access logs"
  type        = string
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the ALB"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID for the ALB and target group"
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS listener"
  type        = string
  default     = "null"
}

variable "target_group_port" {
  description = "Port for the target group"
  type        = number
  default     = 80
}

variable "alb_sg_id" {
  description = "Security Group ID for the ALB"
  type        = string
}
