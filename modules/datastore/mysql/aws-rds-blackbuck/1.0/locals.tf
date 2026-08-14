# Local values for computed attributes and password management
locals {
  # Import detection flags
  import_enabled           = lookup(var.instance.spec, "imports", null) != null ? lookup(var.instance.spec.imports, "import_existing", false) : false
  is_db_instance_import    = local.import_enabled && lookup(var.instance.spec.imports, "db_instance_identifier", null) != null
  is_subnet_group_import   = local.import_enabled && lookup(var.instance.spec.imports, "db_subnet_group_name", null) != null
  is_security_group_import = local.import_enabled && lookup(var.instance.spec.imports, "security_group_id", null) != null

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

  # When importing, username and password should be same as the original to avoid overriding existing values
  master_username = local.is_restore_operation ? var.instance.spec.restore_config.restore_master_username : var.instance.spec.version_config.master_username
  master_password = local.is_restore_operation ? var.instance.spec.restore_config.restore_master_password : random_password.master_password[0].result

  # Database name - should be same when importing
  database_name = var.instance.spec.version_config.database_name

  # Max allocated storage (0 means disabled)
  max_allocated_storage = var.instance.spec.sizing.max_allocated_storage > 0 ? var.instance.spec.sizing.max_allocated_storage : null

  # Port mapping for MySQL
  mysql_port = 3306

  # Performance Insights support - only supported on certain instance classes.
  # Confirmed against describe-orderable-db-instance-options for mysql 8.4.9 in ap-south-1:
  # SupportsPerformanceInsights=false for db.t3.micro, db.t3.small, db.t4g.micro and db.t4g.small.
  # The t4g entries matter as much as the t3 ones - enabling PI on an unsupported class fails at apply.
  performance_insights_supported = !contains(["db.t3.micro", "db.t3.small", "db.t4g.micro", "db.t4g.small"], var.instance.spec.sizing.instance_class)

  # Enhanced Security Group Logic
  # Detect if security group exists by name (when not explicitly importing)
  # This logic is evaluated after the data source runs
  sg_exists_by_name = !local.is_security_group_import && length(try(data.aws_security_groups.existing_sg[0].ids, [])) > 0

  # Determine if we should create a new security group
  should_create_security_group = !local.is_security_group_import && !local.sg_exists_by_name

  # Security group source for logging/transparency
  sg_source = local.is_security_group_import ? "imported" : (local.sg_exists_by_name ? "existing" : "created")

  # ---- migration-parity additions (aws-rds-blackbuck) ----
  sec   = lookup(var.instance.spec, "security_config", {})
  pgrp  = lookup(var.instance.spec, "parameter_group", {})
  bkp   = lookup(var.instance.spec, "backup_config", {})
  netcf = lookup(var.instance.spec, "network_config", {})

  # KMS: use the supplied key, else the one this module creates.
  kms_key_arn_input = lookup(local.sec, "kms_key_arn", null)
  create_kms_key    = local.kms_key_arn_input == null || local.kms_key_arn_input == ""
  kms_key_arn       = local.create_kms_key ? aws_kms_key.mysql[0].arn : local.kms_key_arn_input

  # Parameter group: only create one when parameters were actually supplied.
  db_parameters          = lookup(local.pgrp, "parameters", {})
  create_parameter_grp   = length(local.db_parameters) > 0
  parameter_group_name   = local.create_parameter_grp ? aws_db_parameter_group.mysql[0].name : null
  parameter_group_family = "mysql${var.instance.spec.version_config.version}"

  # Backup / maintenance
  backup_retention_period = lookup(local.bkp, "retention_days", 7)
  backup_window           = lookup(local.bkp, "backup_window", "03:00-04:00")
  maintenance_window      = lookup(local.bkp, "maintenance_window", "sun:04:00-sun:05:00")

  # Subnet placement. Fall back to private subnets when the network module did not
  # publish database subnets, so the module still works against an older network.
  use_db_subnets       = lookup(local.netcf, "use_database_subnets", true)
  published_db_subnets = try(var.inputs.vpc_details.attributes.database_subnet_ids, [])
  db_subnet_ids = (local.use_db_subnets && length(local.published_db_subnets) > 0
    ? local.published_db_subnets
  : var.inputs.vpc_details.attributes.private_subnet_ids)

  # Ingress: VPC CIDR is always permitted; extras are additive and validated.
  allowed_cidrs = distinct(concat(
    [var.inputs.vpc_details.attributes.vpc_cidr_block],
    lookup(local.sec, "allowed_cidrs", [])
  ))

  deletion_protection = lookup(local.sec, "deletion_protection", true)
}
