# CloudWatch log group (imported; attributes from live)
resource "aws_cloudwatch_log_group" "main" {
  name              = local.lg.name
  retention_in_days = lookup(local.lg, "retention_in_days", 0)
  kms_key_id        = lookup(local.lg, "kms_key_id", null) != "" ? lookup(local.lg, "kms_key_id", null) : null
  tags              = lookup(local.lg, "tags", {})
}
