# --- AWS Region Configuration --- #
variable "aws_region" {
  description = "The AWS region where resources will be created"
  type        = string
}

# Region where the replication bucket will be created, typically different from the primary region.
variable "replication_region" {
  description = "Region for the replication bucket"
  type        = string
}

# --- AWS Account ID --- #
variable "aws_account_id" {
  description = "AWS account ID for permissions and policies"
  type        = string
}

# --- Environment Label --- #
variable "environment" {
  description = "Environment for the resources (e.g., dev, stage, prod)"
  type        = string
  validation {
    condition     = can(regex("(dev|stage|prod)", var.environment))
    error_message = "The environment must be one of 'dev', 'stage', or 'prod'."
  }
}

# --- Metadata --- #
# Project-level metadata used to generate tags and standardized resource names across all Terraform modules.
# These values are referenced in the centralized metadata.tf file to enforce consistent naming and tagging.

variable "project" {
  description = "Project name or identifier used for tagging AWS resources"
  type        = string
}

variable "application" {
  description = "Logical name of the application or workload deployed in this infrastructure"
  type        = string
}

variable "owner" {
  description = "Owner or responsible person/team for the resources (used for tagging)"
  type        = string
}

# --- Name Prefix for Resources --- #
variable "name_prefix" {
  description = "Prefix for resource names to distinguish environments"
  type        = string
}

# --- VPC Module Configuration --- #

variable "vpc_cidr_block" {
  description = "Primary CIDR block for the VPC"
  type        = string
}

# --- Subnet Configuration Variables --- #

variable "public_subnets" {
  description = "A map of public subnets to create. The key is a logical name for the subnet, and the value is an object with cidr_block and availability_zone."
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
  default = {}
}

variable "private_subnets" {
  description = "A map of private subnets to create. The key is a logical name for the subnet, and the value is an object with cidr_block and availability_zone."
  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))
  default = {}
}

# CloudWatch Flow Log Retention
variable "flow_logs_retention_in_days" {
  description = "Retention period in days for CloudWatch logs"
  type        = number
}

# --- KMS Module Configuration --- #

# Allows enabling or disabling automatic key rotation for the KMS key.
variable "enable_key_rotation" {
  description = "Enable or disable automatic key rotation for the KMS key"
  type        = bool
  default     = true
}

# Root access to the KMS key
# Set to true to include root account (account owner) permissions in the KMS key policy.
# Set to false to enforce least privilege by removing root access from the policy.
variable "kms_root_access" {
  description = "Enable or disable root access in the KMS key policy. Set to false to enforce least privilege."
  type        = bool
  default     = true
}

# Enable or disable the creation of the IAM role for managing the KMS key
# Set to true to create the IAM role and its associated policy for managing the KMS key.
variable "enable_kms_admin_role" {
  description = "Flag to enable or disable the creation of the IAM role for managing the KMS key"
  type        = bool
  default     = false
}

# Enable CloudWatch Monitoring
# This variable controls whether CloudWatch Alarms for the KMS key usage are created.
variable "enable_key_monitoring" {
  description = "Enable or disable CloudWatch Alarms for monitoring KMS key usage."
  type        = bool
  default     = false
}

# Enable alarm for KMS AccessDenied errors (e.g., misconfigured policies or attempts to use key without permissions).
# Recommended for production environments to catch unauthorized usage attempts.
variable "enable_kms_access_denied_alarm" {
  type        = bool
  default     = true
  description = "Enable CloudWatch alarm for KMS AccessDenied errors (recommended in production)."
}

# Threshold for Decrypt Operations
# Defines the threshold for the number of Decrypt operations that trigger a CloudWatch Alarm.
variable "key_decrypt_threshold" {
  description = "Threshold for KMS decrypt operations to trigger an alarm."
  type        = number
  default     = 100 # Example value, adjust as needed.
}

# --- ASG Module Configuration --- #

# Settings for instance, AMI, and key
variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string

  validation {
    condition     = length(var.ami_id) > 0
    error_message = "The ami_id variable must not be empty."
  }
}

variable "instance_type" {
  description = "EC2 instance type (e.g., t2.micro)"
  type        = string
}

variable "s3_scripts" {
  description = "Map of files to be uploaded to the scripts bucket"
  type        = map(string)
  default     = {}
}

variable "autoscaling_min" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
}

variable "autoscaling_max" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
}

variable "desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group; null for dynamic adjustment"
  type        = number
  default     = null
}

variable "health_check_grace_period" {
  description = "The time, in seconds, that Auto Scaling waits before checking the health status of an instance. Should be increased for dev environments with long bootstrap times."
  type        = number
  default     = 300
}

variable "enable_scaling_policies" {
  description = "Enable or disable scaling policies for the ASG"
  type        = bool
  default     = true
}

variable "enable_target_tracking" {
  description = "Enable target tracking scaling policy (recommended)"
  type        = bool
  default     = true
}

variable "enable_data_source" {
  description = "Enable or disable the data source for fetching ASG instance details"
  type        = bool
  default     = false
}

# Threshold for high incoming network traffic. Triggers an alarm when exceeded.
variable "network_in_threshold" {
  description = "Threshold for high incoming network traffic"
  type        = number
}

# Threshold for high outgoing network traffic. Triggers an alarm when exceeded.
variable "network_out_threshold" {
  description = "Threshold for high outgoing network traffic"
  type        = number
}

variable "scale_out_cpu_threshold" {
  description = "CPU utilization threshold for scaling out"
  type        = number
}

variable "scale_in_cpu_threshold" {
  description = "CPU utilization threshold for scaling in"
  type        = number
}

# Enable or disable the Scale-Out Alarm
variable "enable_scale_out_alarm" {
  description = "Enable or disable the Scale-Out Alarm for ASG"
  type        = bool
  default     = true
}

# Enable or disable the Scale-In Alarm
variable "enable_scale_in_alarm" {
  description = "Enable or disable the Scale-In Alarm for ASG"
  type        = bool
  default     = true
}

# Enable or disable the ASG Status Check Alarm
variable "enable_asg_status_check_alarm" {
  description = "Enable or disable the ASG Status Check Alarm"
  type        = bool
  default     = false
}

# Enable or disable the High Network-In Alarm
variable "enable_high_network_in_alarm" {
  description = "Enable or disable the High Network-In Alarm for ASG"
  type        = bool
  default     = false
}

# Enable or disable the High Network-Out Alarm
variable "enable_high_network_out_alarm" {
  description = "Enable or disable the High Network-Out Alarm for ASG"
  type        = bool
  default     = false
}

# EBS Volume Configuration
variable "volume_size" {
  description = "Size of the EBS volume for the root device in GiB"
  type        = number
}

variable "volume_type" {
  description = "Type of the EBS volume for the root device"
  type        = string
}

variable "enable_ebs_encryption" {
  description = "Enable encryption for ASG EC2 instance root volumes"
  type        = bool
  default     = false
}

# WordPress Configuration

variable "wp_title" {
  description = "Title of the WordPress site"
  type        = string
  sensitive   = true
}

variable "wp_admin_email" {
  description = "Admin email for WordPress"
  type        = string
  sensitive   = true
}

# WordPress Database Configuration

variable "db_name" {
  description = "Name of the WordPress database"
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "Username for the WordPress database"
  type        = string
}

# WordPress Admin Configuration
variable "wp_admin_user" {
  description = "WordPress admin username"
  type        = string
  default     = "admin"
}

# WordPress Version Configuration
# This variable specifies the tag of the WordPress GitHub repository to deploy.
variable "wordpress_version" {
  description = "Tag of the WordPress GitHub repository to deploy. Used by deploy_wordpress.sh"
  type        = string
}

# Ansible Deployment Method
variable "use_ansible_deployment" {
  description = "Controls the deployment method for the 'dev' environment."
  type        = bool
  default     = true
}

# --- RDS Module Configuration --- #

# Storage size in GB for the RDS instance
variable "allocated_storage" {
  description = "Storage size in GB for the RDS instance"
  type        = number
}

# Instance class for RDS
variable "instance_class" {
  description = "Instance class for RDS"
  type        = string
}

# Database engine for the RDS instance (e.g., 'mysql', 'postgres')
variable "engine" {
  description = "Database engine for the RDS instance (e.g., 'mysql', 'postgres')"
  type        = string
}

# Database engine version
variable "engine_version" {
  description = "Database engine version"
  type        = string
}

# Database port for RDS (e.g., 3306 for MySQL)
variable "db_port" {
  description = "Database port for RDS (e.g., 3306 for MySQL)"
  type        = number
}

# Number of days to retain RDS backups
variable "backup_retention_period" {
  description = "Number of days to retain RDS backups"
  type        = number
}

# Preferred window for automated RDS backups
variable "backup_window" {
  description = "Preferred window for automated RDS backups"
  type        = string
}

# Enable Multi-AZ deployment for RDS high availability
variable "multi_az" {
  description = "Enable Multi-AZ deployment for RDS high availability"
  type        = bool
}

# Enable or disable deletion protection for RDS instance
variable "rds_deletion_protection" {
  description = "Enable or disable deletion protection for RDS instance"
  type        = bool
}

# Skip final snapshot when deleting the RDS instance
variable "skip_final_snapshot" {
  description = "Skip final snapshot when deleting the RDS instance"
  type        = bool
}

# Enable or disable enhanced monitoring for RDS instances
variable "enable_rds_monitoring" {
  description = "Enable or disable enhanced monitoring for RDS instances"
  type        = bool
  default     = false
}

# PHP version for WordPress installation
variable "php_version" {
  description = "PHP version used for WordPress installation"
  type        = string
}

# RDS Log Retention Period
variable "rds_log_retention_days" {
  description = "Number of days to retain RDS logs in CloudWatch"
  type        = number
  default     = 30
}

# Threshold for CPU utilization alarm
variable "rds_cpu_threshold_high" {
  description = "Threshold for high CPU utilization on RDS"
  type        = number
}

# Threshold for free storage space alarm
variable "rds_storage_threshold" {
  description = "Threshold for low free storage space on RDS (in bytes)"
  type        = number
}

# Threshold for high database connections alarm
variable "rds_connections_threshold" {
  description = "Threshold for high number of database connections on RDS"
  type        = number
}

# Enable or disable specific CloudWatch Alarms
variable "enable_low_storage_alarm" {
  description = "Enable the CloudWatch Alarm for low storage on RDS"
  type        = bool
  default     = true
}

variable "enable_high_cpu_alarm" {
  description = "Enable the CloudWatch Alarm for high CPU utilization on RDS"
  type        = bool
  default     = true
}

variable "enable_high_connections_alarm" {
  description = "Enable the CloudWatch Alarm for high database connections on RDS"
  type        = bool
  default     = true
}

# Number of read replicas to create for the RDS instance
variable "read_replicas_count" {
  description = "Number of read replicas to create for the RDS instance"
  type        = number
}

# Toggle for enabling or disabling Performance Insights
variable "performance_insights_enabled" {
  description = "Enable or disable Performance Insights for RDS instance"
  type        = bool
}

# --- S3 Module Variables --- #

variable "default_region_buckets" {
  type = map(object({
    enabled               = optional(bool, false)
    versioning            = optional(bool, false)
    replication           = optional(bool, false)
    server_access_logging = optional(bool, false)
    region                = optional(string, null) # Optional: region (defaults to provider)
  }))
  description = "Config for default AWS region buckets." # Description: Default region buckets config
  default     = {}
}

variable "replication_region_buckets" {
  type = map(object({
    enabled               = optional(bool, false)
    versioning            = optional(bool, false) # Versioning MUST be enabled for replication destinations
    server_access_logging = optional(bool, false)
    region                = string # AWS region for the replication bucket (REQUIRED)
  }))
  description = "Configuration for S3 buckets specifically in the replication AWS region."
  default     = {}
}

# Enable CORS configuration for the WordPress media bucket
variable "enable_cors" {
  description = "Enable or disable CORS configuration for the WordPress media bucket."
  type        = bool
  default     = false # Set to true in `terraform.tfvars` to enable CORS for the WordPress media bucket
}

# Allowed origins
variable "allowed_origins" {
  description = "List of allowed origins for S3 bucket CORS"
  type        = list(string)
  default     = ["https://example.com"]
}

# Lifecycle Configuration
# Number of days to retain noncurrent object versions
variable "noncurrent_version_retention_days" {
  description = "Number of days to retain noncurrent versions of objects in S3 buckets"
  type        = number
}

# Enable DynamoDB for State Locking
# Controls the creation of the DynamoDB table for state locking.
variable "enable_dynamodb" {
  description = "Enable DynamoDB table for state locking."
  type        = bool
  default     = false

  # Ensures DynamoDB is only enabled when S3 bucket are active.
  validation {
    condition     = var.enable_dynamodb ? contains(keys(var.default_region_buckets), "terraform_state") && var.default_region_buckets["terraform_state"].enabled : true
    error_message = "enable_dynamodb requires `terraform_state` bucket to be enabled."
  }
}

# The folder prefix inside the wordpress_media bucket that will trigger the image processing Lambda function.
variable "wordpress_media_uploads_prefix" {
  description = "The prefix within the wordpress_media bucket where original uploads occur (e.g., 'uploads/')."
  type        = string
  default     = "uploads/"
}

# --- SNS Topic Variables --- #

# List of additional SNS subscriptions (e.g., SMS, Slack)
variable "sns_subscriptions" {
  description = "List of additional SNS subscriptions (e.g., SMS, Slack)"
  type = list(object({
    protocol = string
    endpoint = string
  }))
  default = []
}

# --- ElastiCache Module Variables --- #

variable "redis_version" {
  description = "Redis version for the ElastiCache cluster"
  type        = string
}

variable "node_type" {
  description = "Node type for the ElastiCache cluster"
  type        = string
}

variable "replicas_per_node_group" {
  description = "Number of replicas per shard"
  type        = number
  validation {
    condition     = var.replicas_per_node_group >= 0
    error_message = "replicas_per_node_group must be a non-negative integer."
  }
}

variable "num_node_groups" {
  description = "Number of shards (node groups)"
  type        = number
  validation {
    condition     = var.num_node_groups > 0
    error_message = "num_node_groups must be greater than zero."
  }
}

variable "enable_failover" {
  description = "Enable or disable automatic failover for Redis replication group"
  type        = bool
  default     = false
  validation {
    condition     = var.enable_failover ? var.replicas_per_node_group > 0 : true
    error_message = "Automatic failover can only be enabled if replicas_per_node_group > 0."
  }
}

variable "redis_port" {
  description = "Port for the Redis cluster"
  type        = number
}

variable "snapshot_retention_limit" {
  description = "Number of backups to retain for the Redis cluster"
  type        = number
}

variable "snapshot_window" {
  description = "Time window for Redis backups (e.g., '03:00-04:00')"
  type        = string
}

# Threshold values for CloudWatch alarms related to Redis performance.
variable "redis_cpu_threshold" {
  description = "CPU utilization threshold for Redis alarms"
  type        = number
}

variable "redis_memory_threshold" {
  description = "Memory usage threshold for Redis alarms"
  type        = number
}

# Enable Freeable Memory Alarm for Redis
variable "enable_redis_low_memory_alarm" {
  description = "Enable or disable the freeable memory alarm for Redis"
  type        = bool
  default     = false # Set to true to enable the alarm
}

# Enable High CPU Utilization Alarm for Redis
variable "enable_redis_high_cpu_alarm" {
  description = "Enable or disable the high CPU utilization alarm for Redis"
  type        = bool
  default     = false # Set to true to enable the alarm
}

# Enable Replication Bytes Used Alarm
variable "enable_redis_replication_bytes_alarm" {
  description = "Enable or disable the ReplicationBytesUsed alarm. Relevant only for configurations with replicas."
  type        = bool
  default     = false

  validation {
    condition     = !(var.enable_redis_replication_bytes_alarm && var.replicas_per_node_group == 0)
    error_message = "ReplicationBytesUsed alarm can only be enabled if replicas_per_node_group > 0."
  }
}

variable "redis_cpu_credits_threshold" {
  description = "Threshold for Redis CPU credits alarm. Relevant for burstable instances."
  type        = number
  default     = 5
}

# Threshold for Replication Bytes Used Alarm
variable "redis_replication_bytes_threshold" {
  description = "Threshold (in bytes) for replication bytes used alarm in Redis."
  type        = number
  default     = 50000000 # Example threshold: 50 MB
}

# Enable Low CPU Credits Alarm for Redis
variable "enable_redis_low_cpu_credits_alarm" {
  description = "Enable or disable the low CPU credits alarm for Redis"
  type        = bool
  default     = false # Set to true to enable the alarm
}

# --- ALB Module Variables --- #

# Deletion Protection Variable for ALB
# This variable is specific to the ALB module and controls deletion protection for the ALB.
# - Default value: false (in `alb/variables.tf`).
# - Recommended: Set to true for production (prod) in `terraform.tfvars` for enhanced safety.
variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for the ALB (recommended for prod)"
  type        = bool
  default     = false
}

# Enable or disable HTTPS Listener
variable "enable_https_listener" {
  description = "Enable or disable the creation of the HTTPS Listener"
  type        = bool
  default     = false
}

# Enable or disable ALB access logs
variable "enable_alb_access_logs" {
  description = "Enable or disable ALB access logs"
  type        = bool
  default     = true # Logging is enabled by default
}

# Enable High Request Count Alarm
# Controls the creation of a CloudWatch Alarm for high request count on the ALB.
variable "enable_high_request_alarm" {
  description = "Enable or disable the CloudWatch alarm for high request count on the ALB."
  type        = bool
  default     = false
}

# Enable 5XX Error Alarm
# Controls the creation of a CloudWatch Alarm for HTTP 5XX errors on the ALB.
variable "enable_5xx_alarm" {
  description = "Enable or disable the CloudWatch alarm for HTTP 5XX errors on the ALB."
  type        = bool
  default     = false
}

# Enable Target Response Time Alarm
# Controls the creation of a CloudWatch Alarm for Target Response Time.
# true: The metric is created. false: The metric is not created.
variable "enable_target_response_time_alarm" {
  description = "Enable or disable the CloudWatch alarm for Target Response Time."
  type        = bool
  default     = false
}

# Toggle WAF for ALB
variable "enable_alb_waf" {
  description = "Enable or disable WAF for ALB" # Description of the variable
  type        = bool                            # Boolean type for true/false values
  default     = false                           # Default value is false
}

# Enable WAF Logging
# This variable controls the creation of WAF logging resources. WAF logging will be enabled only if:
# 1. `enable_waf_logging` is set to true.
# 2. Firehose (`enable_firehose`) is also enabled, as it is required for delivering logs.
# By default, WAF logging is disabled.
variable "enable_alb_waf_logging" {
  description = "Enable or disable logging for WAF independently of WAF enablement"
  type        = bool
  default     = false
}

# Enable or disable Firehose and related resources
variable "enable_alb_firehose" {
  description = "Enable or disable Firehose and related resources"
  type        = bool
  default     = false
}

# Enable or disable CloudWatch logging for Firehose delivery stream
variable "enable_alb_firehose_cloudwatch_logs" {
  description = "Enable CloudWatch logging for Firehose delivery stream. Useful for debugging failures."
  type        = bool
  default     = false
}

# --- CloudFront Module Variables --- #
# These variables are passed to the CloudFront module to control its behavior.

variable "wordpress_media_cloudfront_enabled" {
  description = "Set to true to enable the CloudFront distribution for WordPress media files."
  type        = bool
  default     = true
}

variable "cloudfront_price_class" {
  description = "The price class for the CloudFront distribution. 'PriceClass_100', 'PriceClass_200', or 'PriceClass_All'."
  type        = string
  default     = "PriceClass_100"
  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "Invalid CloudFront price class. Must be 'PriceClass_100', 'PriceClass_200', or 'PriceClass_All'."
  }
}

variable "enable_cloudfront_waf" {
  description = "Set to true to enable AWS WAFv2 Web ACL protection for the CloudFront distribution."
  type        = bool
  default     = false
}

variable "enable_cloudfront_firehose" {
  description = "Set to true to enable Kinesis Firehose for AWS WAF logging. This is required if `enable_cloudfront_waf` is true."
  type        = bool
  default     = false
}

variable "enable_cloudfront_standard_logging_v2" {
  description = "Enable CloudFront standard logging (v2) to CloudWatch Logs and S3"
  type        = bool
  default     = true
}

variable "enable_origin_shield" {
  description = "Set to true to enable CloudFront Origin Shield for the primary ALB origin. This adds a caching layer to reduce origin load."
  type        = bool
  default     = false
}

# --- CloudTrail Variables --- #

variable "cloudtrail_logs_retention_in_days" {
  description = "Retention period (in days) for CloudTrail logs in CloudWatch"
  type        = number
  default     = 30
}

# --- Interface Endpoints Module Variables --- #

variable "enable_interface_endpoints" {
  description = "Enable or disable Interface VPC Endpoints (SSM, CloudWatch, KMS, etc.)"
  type        = bool
  default     = false
}

variable "interface_endpoint_services" {
  description = "A list of AWS services for which to create interface endpoints. If null, the module's default list will be used."
  type        = list(string)
  default     = null
}

# --- CloudWatch Variables --- #

variable "enable_cloudwatch_logs" {
  type        = bool
  description = "Enables or disables creation of CloudWatch log groups for EC2 instances (user-data, system, Nginx, PHP-FPM)"
  default     = true # Default ON
}

variable "cw_logs_retention_in_days" {
  type        = number
  description = "Number of days to retain CloudWatch log data for all EC2-related logs (user-data, system, Nginx, PHP-FPM)"
  default     = 365

  validation {
    condition     = var.cw_logs_retention_in_days >= 1
    error_message = "Log retention must be at least 1 day."
  }
}

# --- Secrets Manager Variables --- #

# Random Secrets Versioning
# This variable is used to trigger the re-creation of all random secrets.
variable "secrets_version" {
  description = "A version identifier (e.g., release number '1.2.0' or a date '2025-06-17') to trigger the re-creation of ALL random secrets. Change this to rotate credentials during a new AMI rollout."
  type        = string
  default     = "1.0.0"
}

# Secrets Manager Secret Names

variable "wordpress_secret_name" {
  description = "The name of the Secrets Manager secret for WordPress credentials"
  type        = string
}

variable "redis_auth_secret_name" {
  description = "The name of the Secrets Manager secret for Redis AUTH token"
  type        = string
}

variable "rds_secret_name" {
  description = "The name of the AWS Secrets Manager secret for RDS credentials."
  type        = string
  default     = "rds-secrets"
}

# --- Custom Domain, SSL and DNS Configuration --- #

variable "create_dns_and_ssl" {
  description = "Master switch. Set to true to create ACM, Route53, and all related resources for a custom domain."
  type        = bool
  default     = false
}

variable "custom_domain_name" {
  description = "The root domain name to configure, e.g., 'example.com'."
  type        = string
  default     = ""
}

variable "subject_alternative_names" {
  description = "A list of subject alternative names (SANs) for the certificate, e.g., [\"www.example.com\"]"
  type        = list(string)
  default     = []
}

# --- Feature Lambda Flags --- #

variable "enable_image_processor" {
  description = "A master switch to enable or disable all resources related to the image processing Lambda feature (Lambda, Layer, SQS DLQ)."
  type        = bool
  default     = true
}

# --- Lambda Layer Module Variables --- #

variable "layer_name" {
  description = "The name for the Pillow dependency layer."
  type        = string
}

variable "layer_runtime" {
  description = "The runtime for the layer, must match the Lambda function's runtime."
  type        = list(string)
  default     = ["python3.12"]
}

variable "layer_architecture" {
  description = "The instruction set architecture for the layer."
  type        = list(string)
  default     = ["x86_64"]
}

variable "library_version" {
  description = "The specific version of the Pillow library to be packaged in the layer."
  type        = string
}

# --- SQS Module Variables --- #

variable "sqs_queues" {
  description = <<-EOT
  A map of SQS queues to create. The key of the map is a logical name (e.g., "image-processing")
  used for references between resources and in outputs.

  Each object in the map defines a single queue and its properties:
  - name: (String) The base name of the queue.
  - is_dlq: (Bool) Set to 'true' if this queue's primary purpose is to be a Dead Letter Queue.
  - dlq_key: (Optional String) The key of another queue within this map to use as the DLQ.
  - max_receive_count: (Optional Number) The number of times a message is received before being sent to the DLQ.
  - visibility_timeout_seconds: (Optional Number) The duration that a message is hidden from a consumer.
  - message_retention_seconds: (Optional Number) The duration for which SQS retains a message.
  - kms_data_key_reuse_period_seconds: (Optional Number) The duration SQS can reuse a data key.
  EOT
  type = map(object({
    name                              = string
    is_dlq                            = bool
    dlq_key                           = optional(string)
    max_receive_count                 = optional(number, 10)
    visibility_timeout_seconds        = optional(number, 30)
    message_retention_seconds         = optional(number, 345600)
    kms_data_key_reuse_period_seconds = optional(number, 300)
  }))
  default = {}
}

# --- DynamoDB Module Variables --- #

variable "dynamodb_table_name" {
  description = "The base name for the DynamoDB table (e.g., 'image-metadata')."
  type        = string
}

variable "dynamodb_provisioned_autoscaling" {
  description = "If this object is configured, the table will be created in PROVISIONED mode with autoscaling. If null (default), the table will be in PAY_PER_REQUEST mode."
  type = object({
    read_min_capacity        = number
    read_max_capacity        = number
    read_target_utilization  = number
    write_min_capacity       = number
    write_max_capacity       = number
    write_target_utilization = number
  })
}

variable "dynamodb_table_class" {
  description = "The storage class for the DynamoDB table (STANDARD or STANDARD_INFREQUENT_ACCESS)."
  type        = string
}

variable "dynamodb_hash_key_name" {
  description = "The name of the partition key (hash key) for the table."
  type        = string
}

variable "dynamodb_hash_key_type" {
  description = "The type of the primary partition key (S, N, or B)."
  type        = string
}

variable "dynamodb_range_key_name" {
  description = "Optional: The name of the sort key for the metadata table."
  type        = string
}

variable "dynamodb_range_key_type" {
  description = "Optional: The type of the sort key for the metadata table."
  type        = string
}

variable "dynamodb_gsi" {
  description = "A list of global secondary indexes..."
  type = list(object({
    name               = string
    hash_key           = string
    hash_key_type      = string
    range_key          = optional(string)
    range_key_type     = optional(string)
    projection_type    = string
    non_key_attributes = optional(list(string))
  }))
  default = []
}

variable "enable_dynamodb_point_in_time_recovery" {
  description = "Enables Point-in-Time Recovery (PITR) for the metadata table."
  type        = bool
}

variable "dynamodb_deletion_protection_enabled" {
  description = "Enables deletion protection for the metadata table."
  type        = bool
}

variable "enable_dynamodb_ttl" {
  description = "Enables Time-to-Live (TTL) feature for the metadata table."
  type        = bool
}

variable "dynamodb_ttl_attribute_name" {
  description = "The attribute name for TTL records in the metadata table."
  type        = string
}

# --- Lambda Images (Processor) Module Variables --- #

variable "lambda_function_name" {
  description = "The base name for the image processing Lambda function."
  type        = string
  default     = "image-processor"
}

variable "lambda_runtime" {
  description = "The runtime for the Lambda function. Must match the layer's runtime."
  type        = string
  default     = "python3.12"
}

variable "lambda_architecture" {
  description = "The instruction set architecture for the Lambda function. Must match the layer's architecture."
  type        = string
  default     = "x86_64"
}

variable "lambda_memory_size" {
  description = "The amount of memory in MB for the Lambda function."
  type        = number
  default     = 256
}

variable "lambda_timeout" {
  description = "The timeout in seconds for the Lambda function."
  type        = number
  default     = 60
}

variable "sqs_batch_size" {
  description = "The maximum number of SQS messages to process in a single batch."
  type        = number
  default     = 5
}

variable "lambda_destination_prefix" {
  description = "The destination prefix (folder) in the S3 bucket for processed images."
  type        = string
  default     = "processed/"
}

variable "lambda_environment_variables" {
  description = "A map of static environment variables to be passed to the Lambda function's runtime."
  type        = map(string)
  default     = {}
}

variable "enable_lambda_alarms" {
  description = "Enable or disable the creation of CloudWatch alarms for the Lambda function."
  type        = bool
  default     = true
}

variable "lambda_iam_policy_attachments" {
  description = "A list of additional, pre-existing IAM policy ARNs to attach to the Lambda's role."
  type        = list(string)
  default     = []
}

variable "enable_lambda_tracing" {
  description = "If true, enables AWS X-Ray active tracing for the Lambda function."
  type        = bool
  default     = true
}

# --- EFS Module Configuration --- #

variable "enable_efs" {
  description = "Controls whether the EFS module and its related resources are created. Set to 'false' to use EBS storage only."
  type        = bool
  default     = true
}

variable "enable_efs_lifecycle_policy" {
  description = "Enable or disable the EFS lifecycle policy for cost savings."
  type        = bool
  default     = false
}

variable "efs_transition_to_ia" {
  description = "Specifies when to transition files to the Infrequent Access (IA) storage class. E.g., 'AFTER_30_DAYS'."
  type        = string
  default     = "AFTER_30_DAYS"
}

variable "enable_efs_burst_credit_alarm" {
  description = "Enable an alarm for low EFS burst credits."
  type        = bool
  default     = false
}

variable "efs_burst_credit_threshold" {
  description = "The threshold (in bytes) for the low burst credit balance alarm."
  type        = number
  default     = 1099511627776 # ~1 TiB
}

# EFS Access Point Configuration

variable "efs_access_point_path" {
  description = "The path on the EFS file system for the Access Point."
  type        = string
  default     = "/wordpress"
}

variable "efs_access_point_posix_uid" {
  description = "The POSIX user ID for the EFS Access Point (e.g., '33' for www-data)."
  type        = string
  default     = "33"
}

variable "efs_access_point_posix_gid" {
  description = "The POSIX group ID for the EFS Access Point (e.g., '33' for www-data)."
  type        = string
  default     = "33"
}

# --- Client VPN Module Configuration --- #

variable "enable_client_vpn" {
  description = "Controls whether the Client VPN module is enabled. Set to 'true' to create the VPN endpoint."
  type        = bool
  default     = false
}

variable "client_vpn_split_tunnel" {
  description = "Indicates whether split-tunnel is enabled. If true, only traffic destined for the VPC's CIDR and other specified routes goes through the VPN."
  type        = bool
  default     = true
}

variable "client_vpn_client_cidr_blocks" {
  description = "List of IPv4 address ranges, in CIDR notation, from which to assign client IP addresses (e.g., ['10.100.0.0/22'])."
  type        = list(string)
  default     = []
}

variable "client_vpn_log_retention_days" {
  description = "The number of days to retain Client VPN connection logs."
  type        = number
  default     = 30
}

variable "client_vpn_authentication_type" {
  description = "The authentication method for Client VPN. Valid values are 'certificate' or 'federated'."
  type        = string
  default     = "certificate"
}

variable "client_vpn_saml_provider_arn" {
  description = "The ARN of the IAM SAML identity provider. Required only if authentication_type is 'federated'."
  type        = string
  default     = null
}

variable "client_vpn_enable_self_service_portal" {
  description = "Enable the self-service portal for federated authentication."
  type        = bool
  default     = false
}

variable "client_vpn_access_group_id" {
  description = "The ID of a group to which access is granted (for federated auth)."
  type        = string
  default     = null
}

# --- Notes --- #
# 1. This file contains global variables shared across all modules.
# 2. All environment-specific values (dev, stage, prod) should be defined in terraform.tfvars.
# 3. Validation blocks help prevent invalid configurations at runtime.
