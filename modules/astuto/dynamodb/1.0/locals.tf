# Extract spec and advanced configuration
locals {
  spec         = var.instance.spec
  aws_dynamodb = lookup(lookup(var.instance, "advanced", {}), "aws_dynamodb", {})

  # Transform attributes from map to list format required by DynamoDB
  attributes = [
    for attribute in local.spec.attributes :
    {
      name = attribute.name
      type = attribute.type
    }
  ]

  # Transform global secondary indexes
  global_secondary_indexes = [
    for gsi_name, gsi_config in local.spec.global_secondary_indexes : {
      name               = gsi_config.name
      hash_key           = gsi_config.hash_key
      range_key          = lookup(gsi_config, "range_key", null)
      projection_type    = "ALL"
      non_key_attributes = []
      read_capacity      = lookup(gsi_config, "read_capacity", null)
      write_capacity     = lookup(gsi_config, "write_capacity", null)
    }
  ]

  # Tags merging
  tags = merge({
    "Environment"         = var.environment.name
    "EnvironmentUniqueId" = var.environment.unique_name
  }, lookup(local.spec, "tags", lookup(local.aws_dynamodb, "tags", {})))

  # Table name
  table_name = "${var.instance_name}-${var.environment.unique_name}"

  # Basic configuration
  hash_key                       = local.spec.hash_key
  range_key                      = lookup(local.spec, "range_key", lookup(local.aws_dynamodb, "range_key", null))
  billing_mode                   = lookup(local.spec, "billing_mode", lookup(local.aws_dynamodb, "billing_mode", "PAY_PER_REQUEST"))
  point_in_time_recovery_enabled = lookup(local.spec, "point_in_time_recovery_enabled", lookup(local.aws_dynamodb, "point_in_time_recovery_enabled", false))
  stream_enabled                 = lookup(local.spec, "stream_enabled", lookup(local.aws_dynamodb, "stream_enabled", false))

  # Advanced configuration from advanced.aws_dynamodb
  autoscaling_defaults               = lookup(local.aws_dynamodb, "autoscaling_defaults", { "scale_in_cooldown" : 0, "scale_out_cooldown" : 0, "target_value" : 70 })
  autoscaling_enabled                = lookup(local.aws_dynamodb, "autoscaling_enabled", false)
  autoscaling_indexes                = lookup(local.aws_dynamodb, "autoscaling_indexes", {})
  autoscaling_read                   = lookup(local.aws_dynamodb, "autoscaling_read", {})
  autoscaling_write                  = lookup(local.aws_dynamodb, "autoscaling_write", {})
  create_table                       = lookup(local.aws_dynamodb, "create_table", true)
  local_secondary_indexes            = lookup(local.aws_dynamodb, "local_secondary_indexes", [])
  read_capacity                      = lookup(local.aws_dynamodb, "read_capacity", null)
  replica_regions                    = lookup(local.aws_dynamodb, "replica_regions", [])
  server_side_encryption_enabled     = lookup(local.aws_dynamodb, "server_side_encryption_enabled", false)
  server_side_encryption_kms_key_arn = lookup(local.aws_dynamodb, "server_side_encryption_kms_key_arn", null)
  stream_view_type                   = lookup(local.aws_dynamodb, "stream_view_type", null)
  table_class                        = lookup(local.aws_dynamodb, "table_class", null)
  timeouts                           = lookup(local.aws_dynamodb, "timeouts", { "create" : "10m", "delete" : "10m", "update" : "60m" })
  ttl_attribute_name                 = lookup(local.aws_dynamodb, "ttl_attribute_name", "")
  ttl_enabled                        = lookup(local.aws_dynamodb, "ttl_enabled", false)
  write_capacity                     = lookup(local.aws_dynamodb, "write_capacity", null)

  # Use spec GSI if provided, otherwise fall back to advanced
  final_global_secondary_indexes = length(local.global_secondary_indexes) > 0 ? local.global_secondary_indexes : lookup(local.aws_dynamodb, "global_secondary_indexes", [])
}

# Output attributes and interfaces
locals {
  output_attributes = {
    table_name        = try(aws_dynamodb_table.this[0].id, aws_dynamodb_table.autoscaled[0].id, "")
    table_arn         = try(aws_dynamodb_table.this[0].arn, aws_dynamodb_table.autoscaled[0].arn, "")
    read_only_policy  = aws_iam_policy.read_only_policy.arn
    read_write_policy = aws_iam_policy.read_write_policy.arn
    stream_arn        = local.stream_enabled ? try(aws_dynamodb_table.this[0].stream_arn, aws_dynamodb_table.autoscaled[0].stream_arn, "") : null
    stream_label      = local.stream_enabled ? try(aws_dynamodb_table.this[0].stream_label, aws_dynamodb_table.autoscaled[0].stream_label, "") : null
  }

  output_interfaces = {}
}
