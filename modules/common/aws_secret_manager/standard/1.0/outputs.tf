# Define your outputs here
locals {
  output_interfaces = {}
  output_attributes = {
    secret_name         = aws_secretsmanager_secret.secret-manager-secret.name
    secret_id           = aws_secretsmanager_secret.secret-manager-secret.id
    secret_arn          = aws_secretsmanager_secret.secret-manager-secret.arn
    secret_version_arn  = aws_secretsmanager_secret_version.secret-manager-version.arn
    secret_version_id   = aws_secretsmanager_secret_version.secret-manager-version.version_id
    rotation_enabled    = local.rotation_enabled
    rotation_lambda_arn = local.rotation_lambda_arn
  }
}