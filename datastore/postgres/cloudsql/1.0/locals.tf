# Generate unique instance identifier
locals {
  instance_identifier = "${var.instance_name}-${var.environment.unique_name}"

  # Determine master username and password based on restore scenario
  master_username = var.instance.spec.restore_config.restore_from_backup ? var.instance.spec.restore_config.master_username : "postgres"
  master_password = var.instance.spec.restore_config.restore_from_backup ? var.instance.spec.restore_config.master_password : random_password.master_password[0].result
}