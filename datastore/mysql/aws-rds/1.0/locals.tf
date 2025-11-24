# Local values for computed attributes and password management
locals {
  # Import detection flags
  is_db_instance_import    = lookup(var.instance.spec, "imports", null) != null ? lookup(var.instance.spec.imports, "db_instance_identifier", null) != null : false
  is_subnet_group_import   = lookup(var.instance.spec, "imports", null) != null ? lookup(var.instance.spec.imports, "db_subnet_group_name", null) != null : false
  is_security_group_import = lookup(var.instance.spec, "imports", null) != null ? lookup(var.instance.spec.imports, "security_group_id", null) != null : false

  # Resource identifiers - use imported values if available, otherwise generate new names
  db_identifier       = local.is_db_instance_import ? var.instance.spec.imports.db_instance_identifier : "${var.instance_name}-${var.environment.unique_name}"
  subnet_group_name   = local.is_subnet_group_import ? var.instance.spec.imports.db_subnet_group_name : "${var.instance_name}-${var.environment.unique_name}-subnet-group"
  security_group_name = "${var.instance_name}-${var.environment.unique_name}-sg"
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

  # Master credentials - don't set when importing (set to null)
  # When importing, username and password should be null to avoid overriding existing values
  master_username = local.is_db_instance_import ? null : (local.is_restore_operation ? var.instance.spec.restore_config.restore_master_username : var.instance.spec.version_config.master_username)
  master_password = local.is_db_instance_import ? null : (local.is_restore_operation ? var.instance.spec.restore_config.restore_master_password : (length(random_password.master_password) > 0 ? random_password.master_password[0].result : ""))

  # Database name - don't set when importing
  database_name = local.is_db_instance_import ? null : var.instance.spec.version_config.database_name

  # Max allocated storage (0 means disabled)
  max_allocated_storage = var.instance.spec.sizing.max_allocated_storage > 0 ? var.instance.spec.sizing.max_allocated_storage : null

  # Port mapping for MySQL
  mysql_port = 3306

  # Performance Insights support - only supported on certain instance classes
  # db.t3.micro and db.t3.small don't support Performance Insights
  performance_insights_supported = !contains(["db.t3.micro", "db.t3.small"], var.instance.spec.sizing.instance_class)

  # Enhanced Security Group Logic
  # Detect if security group exists by name (when not explicitly importing)
  # This logic is evaluated after the data source runs
  sg_exists_by_name = !local.is_security_group_import && length(try(data.aws_security_groups.existing_sg[0].ids, [])) > 0

  # Determine if we should create a new security group
  should_create_security_group = !local.is_security_group_import && !local.sg_exists_by_name

  # Security group source for logging/transparency
  sg_source = local.is_security_group_import ? "imported" : (local.sg_exists_by_name ? "existing" : "created")
}