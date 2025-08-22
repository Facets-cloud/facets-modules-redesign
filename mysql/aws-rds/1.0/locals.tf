# Local values for computed attributes and password management
locals {
  # Generate unique resource names
  db_identifier       = "${var.instance_name}-${var.environment.unique_name}"
  subnet_group_name   = "${var.instance_name}-${var.environment.unique_name}-subnet-group"
  security_group_name = "${var.instance_name}-${var.environment.unique_name}-sg"
  secret_name         = "${var.instance_name}-${var.environment.unique_name}-password"

  # Database configuration
  is_restore_operation = var.instance.spec.restore_config.restore_from_backup

  # Use restore credentials if restoring, otherwise use spec credentials
  master_username = local.is_restore_operation ? var.instance.spec.restore_config.restore_master_username : var.instance.spec.version_config.master_username
  master_password = local.is_restore_operation ? var.instance.spec.restore_config.restore_master_password : random_password.master_password[0].result

  # Max allocated storage (0 means disabled)
  max_allocated_storage = var.instance.spec.sizing.max_allocated_storage > 0 ? var.instance.spec.sizing.max_allocated_storage : null

  # Port mapping for MySQL
  mysql_port = 3306

  # Performance Insights support - only supported on certain instance classes
  # db.t3.micro and db.t3.small don't support Performance Insights
  performance_insights_supported = !contains(["db.t3.micro", "db.t3.small"], var.instance.spec.sizing.instance_class)
}