# Generate random password for master user. Kept even when adopting: it is the fallback
# when no live password is supplied, and it is never applied to an adopted database
# because `password` sits in ignore_changes.
resource "random_password" "master_password" {
  count            = local.is_restore_operation ? 0 : 1
  length           = 16
  special          = true
  upper            = true
  lower            = true
  numeric          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"

  lifecycle {
    ignore_changes = [
      length,
      override_special,
    ]
  }
}

# Create DB subnet group (only if not importing) - handle existing gracefully
resource "aws_db_subnet_group" "mysql" {
  count      = local.is_subnet_group_import ? 0 : 1
  name       = local.subnet_group_name
  subnet_ids = var.inputs.vpc_details.attributes.private_subnet_ids

  tags = merge(var.environment.cloud_tags, {
    Name   = local.subnet_group_name
    Module = "mysql"
    Flavor = "aws-rds"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,      # Ignore name changes for imported resources
      subnet_ids # Ignore changes to subnet IDs for imported resources
    ]
  }
}

# Data source to fetch imported subnet group
data "aws_db_subnet_group" "imported" {
  count = local.is_subnet_group_import ? 1 : 0
  name  = local.subnet_group_name
}

# Data source to check if security group already exists by name
data "aws_security_groups" "existing_sg" {
  count = !local.is_security_group_import ? 1 : 0

  filter {
    name   = "group-name"
    values = [local.security_group_name]
  }

  filter {
    name   = "vpc-id"
    values = [var.inputs.vpc_details.attributes.vpc_id]
  }
}

# Create security group for MySQL (only if not importing AND doesn't already exist)
resource "aws_security_group" "mysql" {
  count       = local.should_create_security_group ? 1 : 0
  name        = local.security_group_name
  description = "Security group for MySQL RDS instance ${var.instance_name}"
  vpc_id      = var.inputs.vpc_details.attributes.vpc_id

  # Allow MySQL access from VPC
  ingress {
    from_port   = local.mysql_port
    to_port     = local.mysql_port
    protocol    = "tcp"
    cidr_blocks = [var.inputs.vpc_details.attributes.vpc_cidr_block]
    description = "MySQL access from VPC"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.environment.cloud_tags, {
    Name   = local.security_group_name
    Module = "mysql"
    Flavor = "aws-rds"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,        # Ignore name changes for imported resources
      vpc_id,      # Ignore VPC changes for imported resources
      description, # Ignore description changes for imported resources
      ingress,     # Ignore ingress rule changes for imported resources
      egress       # Ignore egress rule changes for imported resources
    ]
  }
}

# Data source to fetch imported security group
data "aws_security_group" "imported" {
  count = local.is_security_group_import ? 1 : 0
  id    = local.security_group_id
}

# Local variables for resource references
locals {
  # Get the actual subnet group name (imported or created)
  actual_subnet_group_name = local.is_subnet_group_import ? data.aws_db_subnet_group.imported[0].name : (length(aws_db_subnet_group.mysql) > 0 ? aws_db_subnet_group.mysql[0].name : null)

  # Get the actual security group ID from all sources (imported, existing by name, or created)
  actual_security_group_id = local.is_security_group_import ? data.aws_security_group.imported[0].id : ((length(aws_security_group.mysql) > 0 ? aws_security_group.mysql[0].id : null)
  )

  # Always use the main mysql resource identifier for read replicas
  mysql_instance_identifier = aws_db_instance.mysql.identifier
}

# Create the MySQL RDS instance (handles new, imported, and restored instances)
resource "aws_db_instance" "mysql" {
  # Removed count parameter to allow imports - resource always exists

  # Basic configuration
  identifier     = local.db_identifier
  engine         = "mysql"
  engine_version = var.instance.spec.version_config.version

  # Set only on a read replica. Its presence makes AWS treat this as a replica of
  # the named instance; its absence on an adopted replica would promote it.
  replicate_source_db = local.is_read_replica ? local.replica_source : null

  # Instance configuration
  instance_class        = var.instance.spec.sizing.instance_class
  allocated_storage     = var.instance.spec.sizing.allocated_storage
  max_allocated_storage = local.max_allocated_storage
  storage_type          = var.instance.spec.sizing.storage_type
  storage_encrypted     = true # Always enabled for security

  # Database configuration - use conditional values for importing
  db_name  = local.is_read_replica ? null : local.database_name
  username = local.is_read_replica ? null : local.master_username
  password = local.is_read_replica ? null : local.master_password
  port     = local.mysql_port

  # Network configuration
  db_subnet_group_name   = local.actual_subnet_group_name
  vpc_security_group_ids = [local.actual_security_group_id]
  publicly_accessible    = false # Always private for security

  # Availability and backup - spec-driven, defaulting to the previously hardcoded
  # values so a new database behaves exactly as before.
  multi_az                = local.multi_az
  backup_retention_period = local.backup_retention_period
  backup_window           = local.backup_window
  maintenance_window      = local.maintenance_window

  # Performance and monitoring
  performance_insights_enabled        = local.performance_insights_supported
  monitoring_interval                 = local.monitoring_interval
  monitoring_role_arn                 = local.monitoring_interval > 0 && local.monitoring_role_arn != "" ? local.monitoring_role_arn : null
  enabled_cloudwatch_logs_exports     = local.logs_exports
  auto_minor_version_upgrade          = local.auto_minor_upgrade
  apply_immediately                   = local.apply_immediately
  copy_tags_to_snapshot               = local.copy_tags_to_snapshot
  iam_database_authentication_enabled = local.iam_database_auth
  ca_cert_identifier                  = local.ca_cert_identifier != "" ? local.ca_cert_identifier : null
  iops                                = local.storage_iops > 0 ? local.storage_iops : null
  storage_throughput                  = local.storage_throughput > 0 ? local.storage_throughput : null

  # Deletion protection - NEVER force this off on an adopted database
  deletion_protection       = local.deletion_protection
  skip_final_snapshot       = true
  final_snapshot_identifier = "${local.db_identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Restore configuration - only set when restoring from backup
  dynamic "restore_to_point_in_time" {
    for_each = local.is_restore_operation && !local.is_db_instance_import ? [1] : []
    content {
      source_db_instance_identifier = var.instance.spec.restore_config.source_db_instance_identifier
      use_latest_restorable_time    = true
    }
  }

  # Lifecycle management
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      identifier,        # Ignore identifier changes for imported resources
      apply_immediately, # Input-only: the API never returns it, so import cannot
      # populate it and ANY value reads as an add on the plan.
      # Still honoured on create, so greenfield is unaffected.
      password,                  # Password might be managed externally when importing
      username,                  # Username might be different when importing
      db_name,                   # Database name might be different when importing
      final_snapshot_identifier, # Timestamp will always change
      db_subnet_group_name,      # Ignore subnet group name changes for imported resources
      vpc_security_group_ids,    # Ignore security group changes for imported resources
      engine_version,            # Prevent forced upgrades on imported instances
      storage_type,              # Storage type changes require recreation
      storage_encrypted,         # Encryption cannot be changed after creation
      kms_key_id                 # KMS key changes require recreation
    ]
  }

  tags = local.db_tags
}


# Create read replicas if requested (works with both created and imported instances)
resource "aws_db_instance" "read_replicas" {
  count = var.instance.spec.sizing.read_replica_count

  # Basic configuration
  # Use replica_identifier_base which adds "imp" suffix when importing to avoid conflicts
  identifier = "${local.replica_identifier_base}-replica-${count.index + 1}"
  # IMPORTANT: Use the identifier, not the id, for replication source
  replicate_source_db = local.mysql_instance_identifier

  # Instance configuration (same as master for consistency)
  instance_class = var.instance.spec.sizing.instance_class
  storage_type   = var.instance.spec.sizing.storage_type

  # Network configuration (same security group)
  vpc_security_group_ids = [local.actual_security_group_id]
  publicly_accessible    = false

  # Performance monitoring
  performance_insights_enabled = local.performance_insights_supported
  monitoring_interval          = 0 # Disabled to avoid IAM role requirement

  # No backups for read replicas
  backup_retention_period = 0

  # Deletion protection disabled for testing
  deletion_protection = false
  skip_final_snapshot = true # Read replicas don't need final snapshots

  # Lifecycle management
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      identifier,            # Ignore identifier changes for imported resources
      replicate_source_db,   # Ignore source DB changes for flexibility
      vpc_security_group_ids # Ignore security group changes for imported resources
    ]
  }

  tags = merge(var.environment.cloud_tags, {
    Name   = "${local.replica_identifier_base}-replica-${count.index + 1}"
    Module = "mysql"
    Flavor = "aws-rds"
    Role   = "read-replica"
  })
}

# Import blocks for Terraform to manage existing resources
# These are handled by the Facets platform based on the imports section in facets.yaml

# For imported DB instances, we need to handle certain attributes differently
# The ignore_changes in lifecycle blocks ensure that imported resources
# don't get recreated due to differences in configuration

# Important: When importing resources, the following attributes are ignored:
# - Resource identifiers/names (to prevent recreation)
# - Network configurations (subnet groups, security groups)
# - Ingress/egress rules for security groups
# - Engine version (to prevent forced upgrades)
# - Storage type and encryption (cannot be changed without recreation)
# These can genuinely only be changed by recreating the resources

# When importing existing instances, read replicas get "imp" suffix to avoid conflicts
# with existing unmanaged replicas. This allows gradual migration to Terraform management.

# Password management - using random password generation only for new instances
# For imported instances, passwords are managed externally
# The password is stored in Terraform state and accessible via output interfaces
# For production use, consider external secret management solutions

# Enhanced Security Group Handling:
# The module now supports three security group scenarios:
# 1. EXPLICIT IMPORT: User provides security_group_id in imports section
# 2. EXISTING BY NAME: Security group with same name already exists in VPC 
# 3. CREATE NEW: No existing security group found, creates new one
#
# This prevents the "security group already exists" error by:
# - Using data source to check for existing security groups by name
# - Only creating new security group when none exists and not explicitly importing
# - Transparently using existing security groups when found
# - Providing sg_source output to show which approach was used