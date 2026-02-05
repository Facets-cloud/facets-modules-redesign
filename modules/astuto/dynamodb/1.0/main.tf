################################################################################
# DynamoDB Table (Standard - No Autoscaling)
################################################################################

resource "aws_dynamodb_table" "this" {
  count = local.create_table && !local.autoscaling_enabled ? 1 : 0

  name             = local.table_name
  billing_mode     = local.billing_mode
  hash_key         = local.hash_key
  range_key        = local.range_key
  read_capacity    = local.read_capacity
  write_capacity   = local.write_capacity
  stream_enabled   = local.stream_enabled
  stream_view_type = local.stream_view_type
  table_class      = local.table_class

  ttl {
    enabled        = local.ttl_enabled
    attribute_name = local.ttl_attribute_name
  }

  point_in_time_recovery {
    enabled = local.point_in_time_recovery_enabled
  }

  dynamic "attribute" {
    for_each = local.attributes

    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "local_secondary_index" {
    for_each = local.local_secondary_indexes

    content {
      name               = local_secondary_index.value.name
      range_key          = local_secondary_index.value.range_key
      projection_type    = local_secondary_index.value.projection_type
      non_key_attributes = lookup(local_secondary_index.value, "non_key_attributes", null)
    }
  }

  dynamic "global_secondary_index" {
    for_each = local.final_global_secondary_indexes

    content {
      name               = global_secondary_index.value.name
      hash_key           = global_secondary_index.value.hash_key
      projection_type    = global_secondary_index.value.projection_type
      range_key          = lookup(global_secondary_index.value, "range_key", null)
      read_capacity      = lookup(global_secondary_index.value, "read_capacity", null)
      write_capacity     = lookup(global_secondary_index.value, "write_capacity", null)
      non_key_attributes = lookup(global_secondary_index.value, "non_key_attributes", null)
    }
  }

  dynamic "replica" {
    for_each = local.replica_regions

    content {
      region_name = replica.value.region_name
      kms_key_arn = lookup(replica.value, "kms_key_arn", null)
    }
  }

  server_side_encryption {
    enabled     = local.server_side_encryption_enabled
    kms_key_arn = local.server_side_encryption_kms_key_arn
  }

  tags = merge(
    local.tags,
    {
      "Name" = format("%s", local.table_name)
    },
  )

  timeouts {
    create = lookup(local.timeouts, "create", null)
    delete = lookup(local.timeouts, "delete", null)
    update = lookup(local.timeouts, "update", null)
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [name]
  }
}

################################################################################
# DynamoDB Table (Autoscaled)
################################################################################

resource "aws_dynamodb_table" "autoscaled" {
  count = local.create_table && local.autoscaling_enabled ? 1 : 0

  name             = local.table_name
  billing_mode     = local.billing_mode
  hash_key         = local.hash_key
  range_key        = local.range_key
  read_capacity    = local.read_capacity
  write_capacity   = local.write_capacity
  stream_enabled   = local.stream_enabled
  stream_view_type = local.stream_view_type

  ttl {
    enabled        = local.ttl_enabled
    attribute_name = local.ttl_attribute_name
  }

  point_in_time_recovery {
    enabled = local.point_in_time_recovery_enabled
  }

  dynamic "attribute" {
    for_each = local.attributes

    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "local_secondary_index" {
    for_each = local.local_secondary_indexes

    content {
      name               = local_secondary_index.value.name
      range_key          = local_secondary_index.value.range_key
      projection_type    = local_secondary_index.value.projection_type
      non_key_attributes = lookup(local_secondary_index.value, "non_key_attributes", null)
    }
  }

  dynamic "global_secondary_index" {
    for_each = local.final_global_secondary_indexes

    content {
      name               = global_secondary_index.value.name
      hash_key           = global_secondary_index.value.hash_key
      projection_type    = global_secondary_index.value.projection_type
      range_key          = lookup(global_secondary_index.value, "range_key", null)
      read_capacity      = lookup(global_secondary_index.value, "read_capacity", null)
      write_capacity     = lookup(global_secondary_index.value, "write_capacity", null)
      non_key_attributes = lookup(global_secondary_index.value, "non_key_attributes", null)
    }
  }

  dynamic "replica" {
    for_each = local.replica_regions

    content {
      region_name = replica.value.region_name
      kms_key_arn = lookup(replica.value, "kms_key_arn", null)
    }
  }

  server_side_encryption {
    enabled     = local.server_side_encryption_enabled
    kms_key_arn = local.server_side_encryption_kms_key_arn
  }

  tags = merge(
    local.tags,
    {
      "Name" = format("%s", local.table_name)
    },
  )

  timeouts {
    create = lookup(local.timeouts, "create", null)
    delete = lookup(local.timeouts, "delete", null)
    update = lookup(local.timeouts, "update", null)
  }

  lifecycle {
    ignore_changes  = [read_capacity, write_capacity, name]
    prevent_destroy = true
  }
}

################################################################################
# Autoscaling - Table Read
################################################################################

resource "aws_appautoscaling_target" "table_read" {
  count = local.create_table && local.autoscaling_enabled && length(local.autoscaling_read) > 0 ? 1 : 0

  max_capacity       = local.autoscaling_read["max_capacity"]
  min_capacity       = local.read_capacity
  resource_id        = "table/${aws_dynamodb_table.autoscaled[0].name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "table_read_policy" {
  count = local.create_table && local.autoscaling_enabled && length(local.autoscaling_read) > 0 ? 1 : 0

  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.table_read[0].resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.table_read[0].resource_id
  scalable_dimension = aws_appautoscaling_target.table_read[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.table_read[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    scale_in_cooldown  = lookup(local.autoscaling_read, "scale_in_cooldown", local.autoscaling_defaults["scale_in_cooldown"])
    scale_out_cooldown = lookup(local.autoscaling_read, "scale_out_cooldown", local.autoscaling_defaults["scale_out_cooldown"])
    target_value       = lookup(local.autoscaling_read, "target_value", local.autoscaling_defaults["target_value"])
  }
}

################################################################################
# Autoscaling - Table Write
################################################################################

resource "aws_appautoscaling_target" "table_write" {
  count = local.create_table && local.autoscaling_enabled && length(local.autoscaling_write) > 0 ? 1 : 0

  max_capacity       = local.autoscaling_write["max_capacity"]
  min_capacity       = local.write_capacity
  resource_id        = "table/${aws_dynamodb_table.autoscaled[0].name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "table_write_policy" {
  count = local.create_table && local.autoscaling_enabled && length(local.autoscaling_write) > 0 ? 1 : 0

  name               = "DynamoDBWriteCapacityUtilization:${aws_appautoscaling_target.table_write[0].resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.table_write[0].resource_id
  scalable_dimension = aws_appautoscaling_target.table_write[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.table_write[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    scale_in_cooldown  = lookup(local.autoscaling_write, "scale_in_cooldown", local.autoscaling_defaults["scale_in_cooldown"])
    scale_out_cooldown = lookup(local.autoscaling_write, "scale_out_cooldown", local.autoscaling_defaults["scale_out_cooldown"])
    target_value       = lookup(local.autoscaling_write, "target_value", local.autoscaling_defaults["target_value"])
  }
}

################################################################################
# Autoscaling - Index Read
################################################################################

resource "aws_appautoscaling_target" "index_read" {
  for_each = local.create_table && local.autoscaling_enabled ? local.autoscaling_indexes : {}

  max_capacity       = each.value["read_max_capacity"]
  min_capacity       = each.value["read_min_capacity"]
  resource_id        = "table/${aws_dynamodb_table.autoscaled[0].name}/index/${each.key}"
  scalable_dimension = "dynamodb:index:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "index_read_policy" {
  for_each = local.create_table && local.autoscaling_enabled ? local.autoscaling_indexes : {}

  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.index_read[each.key].resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.index_read[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.index_read[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.index_read[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    scale_in_cooldown  = merge(local.autoscaling_defaults, each.value)["scale_in_cooldown"]
    scale_out_cooldown = merge(local.autoscaling_defaults, each.value)["scale_out_cooldown"]
    target_value       = merge(local.autoscaling_defaults, each.value)["target_value"]
  }
}

################################################################################
# Autoscaling - Index Write
################################################################################

resource "aws_appautoscaling_target" "index_write" {
  for_each = local.create_table && local.autoscaling_enabled ? local.autoscaling_indexes : {}

  max_capacity       = each.value["write_max_capacity"]
  min_capacity       = each.value["write_min_capacity"]
  resource_id        = "table/${aws_dynamodb_table.autoscaled[0].name}/index/${each.key}"
  scalable_dimension = "dynamodb:index:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "index_write_policy" {
  for_each = local.create_table && local.autoscaling_enabled ? local.autoscaling_indexes : {}

  name               = "DynamoDBWriteCapacityUtilization:${aws_appautoscaling_target.index_write[each.key].resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.index_write[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.index_write[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.index_write[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    scale_in_cooldown  = merge(local.autoscaling_defaults, each.value)["scale_in_cooldown"]
    scale_out_cooldown = merge(local.autoscaling_defaults, each.value)["scale_out_cooldown"]
    target_value       = merge(local.autoscaling_defaults, each.value)["target_value"]
  }
}

################################################################################
# IAM Policies for DynamoDB Access
################################################################################

resource "aws_iam_policy" "read_only_policy" {
  name = "${var.environment.unique_name}-${local.table_name}_ro"
  tags = {
    "Environment"         = var.environment.name
    "EnvironmentUniqueId" = var.environment.unique_name
  }
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListAndDescribe"
        Effect = "Allow"
        Action = [
          "dynamodb:List*",
          "dynamodb:DescribeReservedCapacity*",
          "dynamodb:DescribeLimits",
          "dynamodb:DescribeTimeToLive"
        ]
        Resource = "*"
      },
      {
        Sid    = "SpecificTable"
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGet*",
          "dynamodb:DescribeStream",
          "dynamodb:DescribeTable",
          "dynamodb:Get*",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          try(aws_dynamodb_table.this[0].arn, aws_dynamodb_table.autoscaled[0].arn, ""),
          "${try(aws_dynamodb_table.this[0].arn, aws_dynamodb_table.autoscaled[0].arn, "")}/index/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "read_write_policy" {
  name = "${var.environment.unique_name}-${local.table_name}_rw"
  tags = {
    "Environment"         = var.environment.name
    "EnvironmentUniqueId" = var.environment.unique_name
  }
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListAndDescribe"
        Effect = "Allow"
        Action = [
          "dynamodb:List*",
          "dynamodb:DescribeReservedCapacity*",
          "dynamodb:DescribeLimits",
          "dynamodb:DescribeTimeToLive"
        ]
        Resource = "*"
      },
      {
        Sid    = "SpecificTable"
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGet*",
          "dynamodb:DescribeStream",
          "dynamodb:DescribeTable",
          "dynamodb:Get*",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWrite*",
          "dynamodb:CreateTable",
          "dynamodb:Delete*",
          "dynamodb:Update*",
          "dynamodb:PutItem"
        ]
        Resource = [
          try(aws_dynamodb_table.this[0].arn, aws_dynamodb_table.autoscaled[0].arn, ""),
          "${try(aws_dynamodb_table.this[0].arn, aws_dynamodb_table.autoscaled[0].arn, "")}/index/*"
        ]
      }
    ]
  })
}
