# --- Main Configuration for Endpoints --- #

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids # Routing tables for S3 access

  # Using tags
  tags = local.tags
}

# SSM Interface Endpoint (for using SSM in private subnets)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [var.endpoint_sg_id]

  # Using tags
  tags = local.tags
}

# SSM Messages Endpoint
resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [var.endpoint_sg_id]

  # Using tags
  tags = local.tags
}

# EC2 Messages Endpoint for SSM
resource "aws_vpc_endpoint" "ec2_messages" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [var.endpoint_sg_id]

  # Using tags
  tags = local.tags
}

# Tags for endpoints (optional)
locals {
  tags = {
    Name        = "${var.name_prefix}-endpoint"
    Environment = var.environment
  }
}
