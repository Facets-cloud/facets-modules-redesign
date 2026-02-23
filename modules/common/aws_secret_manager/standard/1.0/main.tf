resource "random_string" "suffix" {
  length  = 1
  special = "false"
  upper   = "false"
}

module "secret_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = false
  globally_unique = false
  resource_name   = "${var.instance_name}${random_string.suffix.result}"
  resource_type   = "aws_secret_manager"
  limit           = 60
  environment     = var.environment
}

resource "aws_secretsmanager_secret" "secret-manager-secret" {
  name                    = local.override_default_name ? local.override_name : module.secret_name.name
  description             = local.description
  kms_key_id              = local.kms_key_id
  policy                  = local.policy
  recovery_window_in_days = local.recovery_window_in_days
  tags                    = merge(local.user_defined_tags, var.environment.cloud_tags)
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [name]
  }
}

resource "aws_secretsmanager_secret_version" "secret-manager-version" {
  secret_id     = aws_secretsmanager_secret.secret-manager-secret.id
  secret_string = jsonencode(local.secrets)
}

resource "aws_secretsmanager_secret_policy" "secret-policy" {
  count = local.policy != null ? 1 : 0

  secret_arn = aws_secretsmanager_secret.secret-manager-secret.arn
  policy     = jsonencode(local.policy)
}

resource "aws_secretsmanager_secret_rotation" "secret-rotation" {
  count = local.rotation_enabled && local.rotation_lambda_arn != null ? 1 : 0

  secret_id           = aws_secretsmanager_secret.secret-manager-secret.id
  rotation_lambda_arn = local.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = lookup(local.rotation_rules, "automatically_after_days", null)
    duration                 = lookup(local.rotation_rules, "duration", null)
    schedule_expression      = lookup(local.rotation_rules, "schedule_expression", null)
  }

  rotate_immediately = local.rotate_immediately
}