# Configure AWS provider from inputs
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Generate random password for master user (only if not restoring and not importing)
resource "random_password" "master_password" {
  count            = (local.is_restore_operation || local.is_db_instance_import) ? 0 : 1
  length           = 16
  special          = true
  upper            = true
  lower            = true
  numeric          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Create DB subnet group (only if not importing)
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

# Create security group for MySQL (only if not importing)
resource "aws_security_group" "mysql" {
  count       = local.is_security_group_import ? 0 : 1
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
  actual_subnet_group_name = local.is_subnet_group_import ? data.aws_db_subnet_group.imported[0].name : aws_db_subnet_group.mysql[0].name

  # Get the actual security group ID (imported or created)
  actual_security_group_id = local.is_security_group_import ? data.aws_security_group.imported[0].id : aws_security_group.mysql[0].id
}

# Create the MySQL RDS instance (new instance - not imported, not restored)
resource "aws_db_instance" "mysql" {
  count = (local.is_restore_operation || local.is_db_instance_import) ? 0 : 1

  # Basic configuration
  identifier     = local.db_identifier
  engine         = "mysql"
  engine_version = var.instance.spec.version_config.version

  # Instance configuration
  instance_class        = var.instance.spec.sizing.instance_class
  allocated_storage     = var.instance.spec.sizing.allocated_storage
  max_allocated_storage = local.max_allocated_storage
  storage_type          = var.instance.spec.sizing.storage_type
  storage_encrypted     = true # Always enabled for security

  # Database configuration
  db_name  = var.instance.spec.version_config.database_name
  username = local.master_username
  password = local.master_password
  port     = local.mysql_port

  # Network configuration
  db_subnet_group_name   = local.actual_subnet_group_name
  vpc_security_group_ids = [local.actual_security_group_id]
  publicly_accessible    = false # Always private for security

  # High availability and backup configuration (hardcoded for security)
  multi_az                = true                  # Enable HA by default
  backup_retention_period = 7                     # 7 days retention
  backup_window           = "03:00-04:00"         # 3-4 AM UTC
  maintenance_window      = "sun:04:00-sun:05:00" # Sunday 4-5 AM UTC

  # Performance and monitoring (hardcoded for production readiness)
  performance_insights_enabled    = local.performance_insights_supported
  monitoring_interval             = 0 # Disabled to avoid IAM role requirement
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  # Deletion protection disabled for testing
  deletion_protection       = false
  skip_final_snapshot       = true
  final_snapshot_identifier = "${local.db_identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Lifecycle management
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      identifier,                # Ignore identifier changes for imported resources
      password,                  # Managed by secrets manager
      final_snapshot_identifier, # Timestamp will always change
      db_subnet_group_name,      # Ignore subnet group name changes for imported resources
      vpc_security_group_ids,    # Ignore security group changes for imported resources
      engine_version,            # Prevent forced upgrades on imported instances
      storage_type,              # Storage type changes require recreation
      storage_encrypted,         # Encryption cannot be changed after creation
      kms_key_id                 # KMS key changes require recreation
    ]
  }

  tags = merge(var.environment.cloud_tags, {
    Name   = local.db_identifier
    Module = "mysql"
    Flavor = "aws-rds"
  })
}

# Create the MySQL RDS instance (restored from backup - not imported)
resource "aws_db_instance" "mysql_restored" {
  count = (local.is_restore_operation && !local.is_db_instance_import) ? 1 : 0

  # Basic configuration
  identifier = local.db_identifier

  # Instance configuration
  instance_class        = var.instance.spec.sizing.instance_class
  allocated_storage     = var.instance.spec.sizing.allocated_storage
  max_allocated_storage = local.max_allocated_storage
  storage_type          = var.instance.spec.sizing.storage_type
  storage_encrypted     = true # Always enabled for security

  # Database configuration (restored)
  username = local.master_username
  password = local.master_password
  port     = local.mysql_port

  # Network configuration
  db_subnet_group_name   = local.actual_subnet_group_name
  vpc_security_group_ids = [local.actual_security_group_id]
  publicly_accessible    = false # Always private for security

  # High availability and backup configuration (hardcoded for security)
  multi_az                = true                  # Enable HA by default
  backup_retention_period = 7                     # 7 days retention
  backup_window           = "03:00-04:00"         # 3-4 AM UTC
  maintenance_window      = "sun:04:00-sun:05:00" # Sunday 4-5 AM UTC

  # Performance and monitoring (hardcoded for production readiness)
  performance_insights_enabled    = local.performance_insights_supported
  monitoring_interval             = 0 # Disabled to avoid IAM role requirement
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  # Deletion protection disabled for testing
  deletion_protection       = false
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.db_identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Restore configuration
  restore_to_point_in_time {
    source_db_instance_identifier = var.instance.spec.restore_config.source_db_instance_identifier
    use_latest_restorable_time    = true
  }

  # Lifecycle management
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      identifier,                # Ignore identifier changes for imported resources
      password,                  # Managed by secrets manager
      final_snapshot_identifier, # Timestamp will always change
      db_subnet_group_name,      # Ignore subnet group name changes for imported resources
      vpc_security_group_ids,    # Ignore security group changes for imported resources
      engine_version,            # Prevent forced upgrades on imported instances
      storage_type,              # Storage type changes require recreation
      storage_encrypted,         # Encryption cannot be changed after creation
      kms_key_id                 # KMS key changes require recreation
    ]
  }

  tags = merge(var.environment.cloud_tags, {
    Name   = local.db_identifier
    Module = "mysql"
    Flavor = "aws-rds"
  })
}

# Data source to fetch imported DB instance
data "aws_db_instance" "imported" {
  count                  = local.is_db_instance_import ? 1 : 0
  db_instance_identifier = local.db_identifier
}

# Local to get the actual instance (either new, restored, or imported)
locals {
  mysql_instance = local.is_db_instance_import ? data.aws_db_instance.imported[0] : (local.is_restore_operation ? aws_db_instance.mysql_restored[0] : aws_db_instance.mysql[0])

  # Get the correct identifier for read replica source
  # For imported instances, use the db_instance_identifier attribute
  # For created instances, use the identifier attribute
  mysql_instance_identifier = local.is_db_instance_import ? data.aws_db_instance.imported[0].db_instance_identifier : (local.is_restore_operation ? aws_db_instance.mysql_restored[0].identifier : aws_db_instance.mysql[0].identifier)
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
    prevent_destroy = false
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