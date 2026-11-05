# DynamoDB table (imported; attributes from live)
resource "aws_dynamodb_table" "main" {
  name         = local.t.name
  billing_mode = local.t.billing_mode
  hash_key     = local.t.hash_key
  range_key    = lookup(local.t, "range_key", null)

  read_capacity  = lookup(local.t, "read_capacity", null)
  write_capacity = lookup(local.t, "write_capacity", null)

  dynamic "attribute" {
    for_each = local.t.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  point_in_time_recovery {
    enabled = lookup(local.t, "point_in_time_recovery", false)
  }

  ttl {
    enabled = lookup(local.t, "ttl_enabled", false)
  }

  tags = local.t.tags

  lifecycle {
    prevent_destroy = true
  }
}
