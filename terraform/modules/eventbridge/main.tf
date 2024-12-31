# --- EventBridge Rules and Targets --- #
# This file defines EventBridge rules, their targets, and interactions for scheduling EC2 and ASG tasks,
# as well as automating golden image updates.

# --- EventBridge Rule for Scheduled Tasks --- #
resource "aws_cloudwatch_event_rule" "schedule_rule" {
  count = var.environment != "dev" ? 1 : 0 # Rule is created only in stage/prod

  name                = "${var.name_prefix}-eventbridge-rule"
  description         = "EventBridge rule for scheduling EC2 and ASG tasks"
  schedule_expression = "cron(0 4 ? * 1/2 *)" # Runs every 2 weeks on Monday at 4:00 AM UTC
  is_enabled          = true

  tags = {
    Name        = "${var.name_prefix}-eventbridge-rule"
    Environment = var.environment
  }
}

# --- EventBridge Target for EC2 Tasks --- #
resource "aws_cloudwatch_event_target" "ec2_target" {
  count = var.environment != "dev" ? 1 : 0 # Target is created only in stage/prod

  rule      = aws_cloudwatch_event_rule.schedule_rule[0].name
  arn       = aws_iam_role.eventbridge_role[0].arn # EventBridge assumes this role for execution
  role_arn  = aws_iam_role.eventbridge_role[0].arn
  target_id = "ec2-tasks"

  input = jsonencode({
    action       = "start-instance" # Action type for the target (custom logic)
    resourceType = "EC2"
    instanceId   = var.instance_id
    s3Bucket     = var.scripts_bucket_name       # Bucket where scripts are stored
    s3Key        = "scripts/deploy_wordpress.sh" # Path to the script
  })
}

# --- EventBridge Target for ASG Tasks --- #
resource "aws_cloudwatch_event_target" "asg_target" {
  count = var.environment != "dev" ? 1 : 0 # Target is created only in stage/prod

  rule      = aws_cloudwatch_event_rule.schedule_rule[0].name
  arn       = aws_iam_role.eventbridge_role[0].arn # EventBridge assumes this role for execution
  role_arn  = aws_iam_role.eventbridge_role[0].arn
  target_id = "asg-tasks"

  input = jsonencode({
    action               = "update-asg" # Action type for the target (custom logic)
    resourceType         = "AutoScalingGroup"
    autoScalingGroupName = var.auto_scaling_group_name
    s3Bucket             = var.ami_bucket_name # Bucket where new AMI metadata is stored
    s3Key                = "latest-ami.json"   # Path to the metadata file
  })
}

# --- EventBridge Rule for AMI Update --- #
resource "aws_cloudwatch_event_rule" "ami_update_rule" {
  count = var.environment != "dev" ? 1 : 0 # Rule is created only in stage/prod

  name                = "${var.name_prefix}-ami-update-rule"
  schedule_expression = "rate(14 days)" # Executes every 14 days.
  description         = "EventBridge rule to trigger golden image update every two weeks."

  tags = {
    Name        = "${var.name_prefix}-ami-update-rule"
    Environment = var.environment
  }
}

# --- EventBridge Target for AMI Update --- #
resource "aws_cloudwatch_event_target" "ami_update_target" {
  count     = var.environment != "dev" ? 1 : 0 # Target is created only in stage/prod
  rule      = aws_cloudwatch_event_rule.ami_update_rule[0].name
  target_id = "ami-update-target"

  arn      = var.ami_update_target_arn # ARN of the Lambda or Step Function
  role_arn = aws_iam_role.eventbridge_role[0].arn
}

# --- Notes --- #
# 1. **S3 Usage**:
#    - `scripts_bucket_name`: Used for fetching deployment scripts.
#    - `ami_bucket_name`: Used for fetching new AMI metadata.
#
# 2. **Targets**:
#    - EC2 target fetches deployment scripts from the `scripts` bucket.
#    - ASG target fetches updated AMI metadata from the `ami` bucket.
#    - AMI update target triggers Lambda or Step Function for the golden image update.
#
# 3. **Schedules**:
#    - `schedule_rule`: Runs every 2 weeks on Monday at 4:00 AM UTC for EC2 and ASG tasks.
#    - `ami_update_rule`: Runs every 14 days to trigger golden image updates.
#
# 4. **Best Practices**:
#    - Use `tags` for resource identification.
#    - Ensure IAM roles have only the necessary permissions for execution.
#    - Validate bucket names and keys regularly to ensure availability.
#    - Review `schedule_expression` values for optimal execution timing.