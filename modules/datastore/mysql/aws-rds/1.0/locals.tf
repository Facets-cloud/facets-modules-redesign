# Local values for computed attributes and password management
locals {
  # Import detection flags
  imports_spec             = lookup(var.instance.spec, "imports", null) == null ? {} : var.instance.spec.imports
  import_enabled           = lookup(local.imports_spec, "import_existing", false)
  is_db_instance_import    = local.import_enabled && lookup(var.instance.spec.imports, "db_instance_identifier", null) != null
  is_subnet_group_import   = local.import_enabled && lookup(var.instance.spec.imports, "db_subnet_group_name", null) != null
  is_security_group_import = local.import_enabled && lookup(var.instance.spec.imports, "security_group_id", null) != null

  # Resource identifiers - use imported values if available, otherwise generate new names
  db_identifier       = local.is_db_instance_import ? var.instance.spec.imports.db_instance_identifier : "${var.instance_name}-${var.environment.name}"
  subnet_group_name   = local.is_subnet_group_import ? var.instance.spec.imports.db_subnet_group_name : "${var.instance_name}-${var.environment.name}-subnet-group"
  security_group_name = "${var.instance_name}-${var.environment.name}-sg"
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
  master_username = local.is_restore_operation ? var.instance.spec.restore_config.restore_master_username : "admin"
  # Master password, in precedence order. The LIVE password must win when adopting:
  # this value is not just applied to the instance (it is not - `password` is in
  # ignore_changes), it is what the module hands downstream. outputs.tf feeds it into
  # `password` and into the writer/reader connection_string, so a service wired with
  # ${mysql.<name>.out.interfaces.writer.connection_string} would otherwise receive a
  # RANDOM password for an adopted database and fail to connect.
  # `master_password` is declared optional, so the attribute exists as null when unset -
  # lookup() would return that null, not the "" default. Test for both.
  # Lives in `credentials`, NOT in `imports`: the control plane emits a terraform
  # import block for every imports.* field, and master_password mapped to
  # random_password.master_password - producing a bogus block whose id was the raw
  # "${...}" string. One bad block fails every plan in the environment.
  given_password = try(var.instance.spec.credentials.master_password, null)
  master_password = local.given_password != null && local.given_password != "" ? local.given_password : (
    local.is_restore_operation ? var.instance.spec.restore_config.restore_master_password : (
      length(random_password.master_password) > 0 ? random_password.master_password[0].result : null
    )
  )

  # Database name - should be same when importing
  database_name = var.instance.spec.version_config.database_name

  # Max allocated storage (0 means disabled)
  max_allocated_storage = var.instance.spec.sizing.max_allocated_storage > 0 ? var.instance.spec.sizing.max_allocated_storage : null

  # ── operational policy ────────────────────────────────────────────────────
  # These were hardcoded. On a live estate every one of them disagreed with
  # reality - deletion_protection on all 20 databases, multi_az on 11 - so an
  # apply would have mutated production. They are now resolved from the spec,
  # defaulting to the values that were hardcoded, so greenfield is unchanged.
  # RULE-015: lookup() in locals, never optional() defaults in variables.tf.
  ops = lookup(var.instance.spec, "operations", {})

  multi_az                = lookup(local.ops, "multi_az", true)
  deletion_protection     = lookup(local.ops, "deletion_protection", false)
  backup_retention_period = lookup(local.ops, "backup_retention_period", 7)
  backup_window           = lookup(local.ops, "backup_window", "03:00-04:00")
  maintenance_window      = lookup(local.ops, "maintenance_window", "sun:04:00-sun:05:00")
  monitoring_interval     = lookup(local.ops, "monitoring_interval", 0) != null ? lookup(local.ops, "monitoring_interval", 0) : 0
  monitoring_role_arn     = lookup(local.ops, "monitoring_role_arn", "") != null ? lookup(local.ops, "monitoring_role_arn", "") : ""
  logs_exports            = lookup(local.ops, "cloudwatch_logs_exports", ["error", "general", "slowquery"])
  auto_minor_upgrade      = lookup(local.ops, "auto_minor_version_upgrade", true)

  # Input-only: never read back by import, so SETTING it is always an add on the
  # plan. Emit it only when the document actually asks for it.
  apply_immediately = lookup(local.ops, "apply_immediately", null)

  # Attributes the live estate uses that this module did not model. Defaults are
  # the PROVIDER defaults, so a new database is unchanged; an adopted one states
  # what it already has.
  copy_tags_to_snapshot = lookup(local.ops, "copy_tags_to_snapshot", false)
  iam_database_auth     = lookup(local.ops, "iam_database_authentication_enabled", false)
  ca_cert_identifier    = lookup(local.ops, "ca_cert_identifier", "")

  # gp3 provisioned performance - only emitted when stated, since the defaults are
  # computed by AWS and setting them explicitly would churn every plan.
  storage_iops       = lookup(var.instance.spec.sizing, "iops", 0)
  storage_throughput = lookup(var.instance.spec.sizing, "storage_throughput", 0)

  # Performance Insights: an unsupported class must never have it forced on, but
  # a supported class should follow the document rather than be switched on for it.
  performance_insights_requested = lookup(local.ops, "performance_insights_enabled", true)

  # Tags. Adoption writes them VERBATIM. The default merge would have stripped
  # Hiver's business tags (Classification, Perimeter, Service, Team,
  # DR-Backup-Enabled) off every adopted database and replaced them with Facets
  # metadata - a real change to production, and the same trap the EKS OIDC
  # provider hit.
  spec_tags = lookup(var.instance.spec, "tags", {})
  db_tags = local.import_enabled ? local.spec_tags : merge(
    var.environment.cloud_tags,
    local.spec_tags,
    {
      Name   = local.db_identifier
      Module = "mysql"
      Flavor = "aws-rds"
    }
  )

  # Read replica source. A live replica reports ReadReplicaSourceDBInstanceIdentifier
  # and terraform stores it as replicate_source_db; omitting it from config would ask
  # terraform to PROMOTE the replica to standalone - a destroy and recreate. So a
  # replica is modelled as its own resource that names its source.
  replication     = lookup(var.instance.spec, "replication", {})
  replica_source  = lookup(local.replication, "source_db_identifier", "")
  is_read_replica = local.replica_source != ""

  # Port mapping for MySQL
  mysql_port = 3306

  # Performance Insights support - only supported on certain instance classes
  # db.t3.micro and db.t3.small don't support Performance Insights
  performance_insights_supported = local.performance_insights_requested && !contains(["db.t3.micro", "db.t3.small"], var.instance.spec.sizing.instance_class)

  # Enhanced Security Group Logic
  # Detect if security group exists by name (when not explicitly importing)
  # This logic is evaluated after the data source runs
  sg_exists_by_name = !local.is_security_group_import && length(try(data.aws_security_groups.existing_sg[0].ids, [])) > 0

  # Determine if we should create a new security group
  # Create+manage the SG whenever we are NOT referencing an external one via imports.
  # (Removed the sg_exists_by_name auto-adopt: a data source found the module's OWN
  # just-created SG and flipped count 1->0, destroying it — blocked by prevent_destroy.)
  should_create_security_group = !local.is_security_group_import

  # Security group source for logging/transparency
  sg_source = local.is_security_group_import ? "imported" : (local.sg_exists_by_name ? "existing" : "created")
}