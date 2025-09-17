# Local values for computed attributes and password management
locals {
  # Import detection flags
  is_db_instance_import    = lookup(var.instance.spec, "imports", null) != null ? lookup(var.instance.spec.imports, "db_instance_identifier", null) != null : false
  is_subnet_group_import   = lookup(var.instance.spec, "imports", null) != null ? lookup(var.instance.spec.imports, "db_subnet_group_name", null) != null : false
  is_security_group_import = lookup(var.instance.spec, "imports", null) != null ? lookup(var.instance.spec.imports, "security_group_id", null) != null : false

  # Resource identifiers - use imported values if available, otherwise generate new names
  db_identifier       = local.is_db_instance_import ? var.instance.spec.imports.db_instance_identifier : "${var.instance_name}-${var.environment.unique_name}"
  subnet_group_name   = local.is_subnet_group_import ? var.instance.spec.imports.db_subnet_group_name : "${var.instance_name}-${var.environment.unique_name}-subnet-group"
  security_group_name = local.is_security_group_import ? null : "${var.instance_name}-${var.environment.unique_name}-sg"
  security_group_id   = local.is_security_group_import ? var.instance.spec.imports.security_group_id : null

  # Add suffix to replica names when importing to avoid conflicts with existing replicas
  # This ensures new Terraform-managed replicas don't conflict with pre-existing unmanaged replicas
  # Reserve 15 characters for suffix: "-imp-replica-5" (worst case scenario)
  # This leaves 48 characters for the base identifier when importing, 52 when not importing

  # Helper to truncate without ending on hyphen
  base_for_import = substr(local.db_identifier, 0, 44)
  base_cleaned    = substr(local.base_for_import, -1, 1) == "-" ? substr(local.base_for_import, 0, 43) : local.base_for_import

  replica_identifier_base = local.is_db_instance_import ? substr("${local.base_cleaned}imp", 0, 47) : substr(local.db_identifier, 0, 52)

  # Database configuration
  is_restore_operation = var.instance.spec.restore_config.restore_from_backup

  # Use restore credentials if restoring, otherwise use spec credentials
  # For imported instances, we don't generate new passwords
  master_username = local.is_restore_operation ? var.instance.spec.restore_config.restore_master_username : var.instance.spec.version_config.master_username
  master_password = local.is_restore_operation ? var.instance.spec.restore_config.restore_master_password : (local.is_db_instance_import ? "" : (length(random_password.master_password) > 0 ? random_password.master_password[0].result : ""))
  
  # Max allocated storage (0 means disabled)
  max_allocated_storage = var.instance.spec.sizing.max_allocated_storage > 0 ? var.instance.spec.sizing.max_allocated_storage : null

  # Port mapping for MySQL
  mysql_port = 3306

  # Performance Insights support - only supported on certain instance classes
  # db.t3.micro and db.t3.small don't support Performance Insights
  performance_insights_supported = !contains(["db.t3.micro", "db.t3.small"], var.instance.spec.sizing.instance_class)
}