# --- DynamoDB Table Resource --- #
# This file defines the aws_dynamodb_table resource, making it configurable
# via the variables defined in variables.tf.

# --- Local Values for Attribute Definitions --- #
locals {
  # This block creates a unified map of all unique attributes required by the table's
  # primary key and all Global Secondary Indexes. This avoids defining the same attribute
  # multiple times and ensures all necessary attributes are declared.
  all_attributes = merge(
    # 1. Add the table's primary hash key
    {
      (var.dynamodb_hash_key_name) = {
        name = var.dynamodb_hash_key_name
        type = var.dynamodb_hash_key_type
      }
    },
    # 2. Add the table's primary range key, if it exists
    var.dynamodb_range_key_name != null ? {
      (var.dynamodb_range_key_name) = {
        name = var.dynamodb_range_key_name
        type = var.dynamodb_range_key_type
      }
    } : {},
    # 3. Add all GSI hash keys
    {
      for index in var.dynamodb_gsi :
      index.hash_key => {
        name = index.hash_key
        type = index.hash_key_type
      }
    },
    # 4. Add all GSI range keys, if they exist
    {
      for index in var.dynamodb_gsi :
      index.range_key => {
        name = index.range_key
        type = index.range_key_type
      }
      if lookup(index, "range_key", null) != null
    }
  )
}

# --- DynamoDB Table Resource Definition --- #
# This resource creates the DynamoDB table itself.
resource "aws_dynamodb_table" "dynamodb_table" {
  # The full name is constructed from the prefix, base name, and environment.
  name = "${var.name_prefix}-${var.dynamodb_table_name}-${var.environment}"

  # Billing mode is determined by the presence of the 'dynamodb_provisioned_autoscaling' variable.
  billing_mode = var.dynamodb_provisioned_autoscaling != null ? "PROVISIONED" : "PAY_PER_REQUEST"

  # Set initial capacity for PROVISIONED mode. Ignored in PAY_PER_REQUEST mode.
  read_capacity  = var.dynamodb_provisioned_autoscaling != null ? var.dynamodb_provisioned_autoscaling.read_min_capacity : null
  write_capacity = var.dynamodb_provisioned_autoscaling != null ? var.dynamodb_provisioned_autoscaling.write_min_capacity : null

  # The primary partition key for the table.
  hash_key = var.dynamodb_hash_key_name

  # The range key (sort key) for the table.
  # This argument is ignored by Terraform if the variable value is null.
  range_key = var.dynamodb_range_key_name

  # The storage class of the table, for cost optimization.
  table_class = var.dynamodb_table_class

  # Use the modern, native deletion protection argument.
  deletion_protection_enabled = var.dynamodb_deletion_protection_enabled

  # --- Dynamic Blocks for Schema and Features --- #

  # Dynamically defines all unique attributes required by the table schema
  # (primary key and all GSI keys) by iterating over the unified local map.
  dynamic "attribute" {
    for_each = local.all_attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  # Enables Point-in-Time Recovery based on the variable.
  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  # Enables server-side encryption. Uses a customer key if provided, otherwise an AWS key.
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  # Dynamically enable TTL settings if requested.
  dynamic "ttl" {
    for_each = var.enable_dynamodb_ttl ? [1] : []
    content {
      enabled        = true
      attribute_name = var.dynamodb_ttl_attribute_name
    }
  }

  # Dynamically create Global Secondary Indexes based on the input variable.
  dynamic "global_secondary_index" {
    for_each = { for i, gsi in var.dynamodb_gsi : i => gsi }
    content {
      name               = global_secondary_index.value.name
      hash_key           = global_secondary_index.value.hash_key
      range_key          = lookup(global_secondary_index.value, "range_key", null)
      projection_type    = global_secondary_index.value.projection_type
      non_key_attributes = lookup(global_secondary_index.value, "non_key_attributes", null)
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.dynamodb_table_name}-${var.environment}"
  })
}

# --- DynamoDB Table Autoscaling Configuration --- #
# These resources are created only if the 'dynamodb_provisioned_autoscaling' variable is set.

resource "aws_appautoscaling_target" "read_target" {
  count = var.dynamodb_provisioned_autoscaling != null ? 1 : 0

  max_capacity       = var.dynamodb_provisioned_autoscaling.read_max_capacity
  min_capacity       = var.dynamodb_provisioned_autoscaling.read_min_capacity
  resource_id        = "table/${aws_dynamodb_table.dynamodb_table.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "read_policy" {
  count = var.dynamodb_provisioned_autoscaling != null ? 1 : 0

  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.read_target[0].resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.read_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.read_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.read_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = var.dynamodb_provisioned_autoscaling.read_target_utilization
  }
}

resource "aws_appautoscaling_target" "write_target" {
  count = var.dynamodb_provisioned_autoscaling != null ? 1 : 0

  max_capacity       = var.dynamodb_provisioned_autoscaling.write_max_capacity
  min_capacity       = var.dynamodb_provisioned_autoscaling.write_min_capacity
  resource_id        = "table/${aws_dynamodb_table.dynamodb_table.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "write_policy" {
  count = var.dynamodb_provisioned_autoscaling != null ? 1 : 0

  name               = "DynamoDBWriteCapacityUtilization:${aws_appautoscaling_target.write_target[0].resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.write_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.write_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.write_target[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = var.dynamodb_provisioned_autoscaling.write_target_utilization
  }
}

# --- Notes --- #
# 1. Flexibility: The use of 'dynamic' blocks for 'attribute' and 'global_secondary_index'
#    allows this module to create highly versatile tables without changing the module's code.
# 2. Secure Defaults: The module defaults to 'PAY_PER_REQUEST' billing, enabled
#    Point-in-Time Recovery, and enabled Deletion Protection.
# 3. Intelligent Schema Definition: The module automatically gathers all unique key attributes
#    from the table's primary key and all defined GSIs. This ensures every required attribute
#    is defined with its correct type, preventing schema errors and removing previous limitations.
