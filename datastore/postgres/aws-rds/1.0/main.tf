# PostgreSQL RDS Instance Implementation

resource "random_password" "master_password" {
  count   = var.instance.spec.restore_config.restore_from_backup ? 0 : 1
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
  # Exclude RDS-forbidden characters: /, @, ", space
  override_special = "!#$%&*()-_=+[]{}<>:?"

  lifecycle {
    ignore_changes = [
      length,
      override_special,
    ]
  }
}

# Locals for computed values
locals {
  # Check if we're importing
  is_importing = lookup(var.instance.spec, "imports", null) != null && lookup(var.instance.spec.imports, "db_instance_identifier", null) != null

  # Resource naming with length constraints
  db_instance_identifier = substr("${var.instance_name}-${var.environment.unique_name}", 0, 63)
  subnet_group_name      = substr("${var.instance_name}-${var.environment.unique_name}-subnet-group", 0, 63)
  security_group_name    = substr("${var.instance_name}-${var.environment.unique_name}-sg", 0, 63)

  # Use imported or created subnet group
  actual_subnet_group_name = lookup(var.instance.spec, "imports", null) != null && lookup(var.instance.spec.imports, "subnet_group_name", null) != null ? var.instance.spec.imports.subnet_group_name : (length(aws_db_subnet_group.postgres) > 0 ? aws_db_subnet_group.postgres[0].name : null)

  # Use imported or created security group
  actual_security_group_id = lookup(var.instance.spec, "imports", null) != null && lookup(var.instance.spec.imports, "security_group_id", null) != null ? var.instance.spec.imports.security_group_id : (length(aws_security_group.postgres) > 0 ? aws_security_group.postgres[0].id : null)

  # Determine the correct source DB identifier for replicas
  # Use imported identifier if importing, otherwise use the generated identifier
  replica_source_identifier = local.is_importing ? lookup(var.instance.spec.imports, "db_instance_identifier", aws_db_instance.postgres.identifier) : aws_db_instance.postgres.identifier

  # Parameter group name for consistency
  parameter_group_for_replica = "default.postgres${split(".", var.instance.spec.version_config.engine_version)[0]}"

  # Add suffix to replica names when importing to avoid conflicts with existing replicas
  # This ensures new Terraform-managed replicas don't conflict with pre-existing unmanaged replicas
  # Reserve 15 characters for suffix: "-imp-replica-5" (worst case scenario)
  # This leaves 48 characters for the base identifier when importing, 52 when not importing

  # Helper to truncate without ending on hyphen
  base_for_import = substr(local.db_instance_identifier, 0, 44)
  base_cleaned    = substr(local.base_for_import, -1, 1) == "-" ? substr(local.base_for_import, 0, 43) : local.base_for_import

  replica_identifier_base = local.is_importing ? substr("${local.base_cleaned}imp", 0, 47) : substr(local.db_instance_identifier, 0, 52)

  # Master credentials
  master_username = "pgadmin"
  master_password = var.instance.spec.restore_config.restore_from_backup ? var.instance.spec.restore_config.master_password : random_password.master_password[0].result

  # Database configuration
  database_name = var.instance.spec.version_config.database_name

  # Port configuration
  db_port = 5432

  # Storage configuration
  storage_type = "gp3"

  # Backup configuration (hardcoded for security)
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # Common tags
  common_tags = merge(var.environment.cloud_tags, {
    Name            = local.db_instance_identifier
    DatabaseEngine  = "postgres"
    BackupRetention = tostring(local.backup_retention_period)
  })
}

# DB Subnet Group - only create if not importing
resource "aws_db_subnet_group" "postgres" {
  count = lookup(var.instance.spec, "imports", null) != null && lookup(var.instance.spec.imports, "subnet_group_name", null) != null ? 0 : 1

  name       = local.subnet_group_name
  subnet_ids = var.inputs.vpc_details.attributes.private_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.db_instance_identifier}-subnet-group"
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      # Ignore tag changes that might occur outside Terraform
      tags["LastModified"],
    ]
  }
}

# Security Group for RDS - only create if not importing
resource "aws_security_group" "postgres" {
  count = lookup(var.instance.spec, "imports", null) != null && lookup(var.instance.spec.imports, "security_group_id", null) != null ? 0 : 1

  name_prefix = "${local.security_group_name}-"
  vpc_id      = var.inputs.vpc_details.attributes.vpc_id
  description = "Security group for PostgreSQL RDS instance ${local.db_instance_identifier}"

  # Ingress rule for PostgreSQL
  ingress {
    from_port   = local.db_port
    to_port     = local.db_port
    protocol    = "tcp"
    cidr_blocks = [var.inputs.vpc_details.attributes.vpc_cidr_block]
    description = "PostgreSQL access from VPC"
  }

  # Egress rule (minimal required for RDS)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.db_instance_identifier}-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Instance
resource "aws_db_instance" "postgres" {
  # Basic configuration
  identifier     = local.db_instance_identifier
  engine         = "postgres"
  engine_version = var.instance.spec.version_config.engine_version
  instance_class = var.instance.spec.sizing.instance_class

  # Database configuration
  db_name = local.database_name
  # Conditional credentials - only set when not restoring from snapshot or importing
  username = local.master_username
  password = local.master_password
  port     = local.db_port

  # Storage configuration
  allocated_storage     = var.instance.spec.sizing.allocated_storage
  max_allocated_storage = var.instance.spec.sizing.allocated_storage * 2
  storage_type          = local.storage_type
  storage_encrypted     = true # Always encrypted

  # Network configuration
  db_subnet_group_name   = local.actual_subnet_group_name
  vpc_security_group_ids = local.actual_security_group_id != null ? [local.actual_security_group_id] : []
  publicly_accessible    = false # Always private

  # Backup configuration (hardcoded for security)
  backup_retention_period = local.backup_retention_period
  backup_window           = local.backup_window
  maintenance_window      = local.maintenance_window
  copy_tags_to_snapshot   = true

  # High availability (hardcoded for production readiness)
  multi_az = true

  # Monitoring (disable enhanced monitoring to avoid IAM role requirement)
  monitoring_interval          = 0
  performance_insights_enabled = true

  # Snapshot identifier for restore (conditional)
  snapshot_identifier = var.instance.spec.restore_config.restore_from_backup ? var.instance.spec.restore_config.source_db_instance_identifier : null

  # Parameter group (use default for now)
  parameter_group_name = "default.postgres${split(".", var.instance.spec.version_config.engine_version)[0]}"

  # Deletion protection (configurable for testing)
  deletion_protection = var.instance.spec.security_config.deletion_protection

  # Final snapshot configuration - skip snapshots for faster destroy
  skip_final_snapshot = true
  # Don't set final_snapshot_identifier when skipping to avoid validation errors

  tags = local.common_tags

  lifecycle {
    # Comment out prevent_destroy for testing - uncomment for production
    # prevent_destroy = true
    ignore_changes = [
      # Ignore changes that would trigger recreation when importing
      db_subnet_group_name,
      vpc_security_group_ids,
      # Ignore password and username when importing since we don't know them
      username,
      password,
      # Ignore snapshot identifier after initial creation/import
      snapshot_identifier
    ]
  }
}

# Read Replicas (always allow creation based on read_replica_count)
resource "aws_db_instance" "read_replicas" {
  count = var.instance.spec.sizing.read_replica_count

  # Basic configuration
  # Use replica_identifier_base which adds "-imported" suffix when importing to avoid conflicts
  identifier          = "${local.replica_identifier_base}-replica-${count.index + 1}"
  replicate_source_db = local.replica_source_identifier
  instance_class      = var.instance.spec.sizing.instance_class

  # Use same security group as primary
  vpc_security_group_ids = local.actual_security_group_id != null ? [local.actual_security_group_id] : []
  publicly_accessible    = false

  # Storage configuration (inherited from source)
  storage_encrypted = true

  # High availability for replicas
  multi_az = false # Read replicas don't need multi-AZ

  skip_final_snapshot = true

  # Monitoring (disable enhanced monitoring to avoid IAM role requirement)
  monitoring_interval          = 0
  performance_insights_enabled = true

  # Parameter group (use consistent parameter group)
  parameter_group_name = local.parameter_group_for_replica

  tags = merge(local.common_tags, {
    Name = "${local.replica_identifier_base}-replica-${count.index + 1}"
    Role = "ReadReplica"
  })

  lifecycle {
    # Comment out prevent_destroy for testing - uncomment for production
    # prevent_destroy = true
    ignore_changes = [
      # Ignore changes to the source DB after creation
      replicate_source_db,
      # Ignore security group changes that might happen on the primary
      vpc_security_group_ids,
      # Ignore parameter group changes that might occur after primary instance changes
      parameter_group_name
    ]
  }

  # Ensure replicas are created after primary instance is fully created
  depends_on = [aws_db_instance.postgres]
}