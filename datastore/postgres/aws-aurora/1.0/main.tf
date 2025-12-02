# Generate a random password only when NOT restoring from backup AND NOT importing
# PostgreSQL password requirements: no '/', '@', '"', ' ' (space), but allows other special characters
resource "random_password" "master_password" {
  count            = var.instance.spec.restore_config.restore_from_backup ? 0 : 1
  length           = 16
  special          = true
  override_special = "!#$%&*+-=?^_`{|}~" # Safe special characters for Aurora PostgreSQL

  lifecycle {
    ignore_changes = [
      length,
      override_special,
    ]
  }
}

# Generate unique cluster identifier
locals {
  # Use imported identifier if provided, otherwise generate new one
  cluster_identifier  = try(var.instance.spec.imports.cluster_identifier, null) != null ? var.instance.spec.imports.cluster_identifier : "${var.instance_name}-${var.environment.unique_name}"
  restore_from_backup = var.instance.spec.restore_config.restore_from_backup
  source_snapshot_id  = var.instance.spec.restore_config.source_snapshot_identifier

  # Check if we're importing existing resources
  is_import = try(var.instance.spec.imports.cluster_identifier, null) != null

  # Get writer instance identifier for import
  imported_writer_id = try(var.instance.spec.imports.writer_instance_identifier, null)

  # Handle password - don't create for restore or import
  master_password = local.restore_from_backup ? var.instance.spec.restore_config.master_password : random_password.master_password[0].result
  master_username = local.restore_from_backup ? var.instance.spec.restore_config.master_username : "postgres"

  # Split reader instance identifiers if provided for import
  reader_instance_ids = try(var.instance.spec.imports.reader_instance_identifiers, null) != null && var.instance.spec.imports.reader_instance_identifiers != "" ? split(",", trimspace(var.instance.spec.imports.reader_instance_identifiers)) : []
}

# Create DB subnet group (skip if importing)
resource "aws_db_subnet_group" "aurora" {
  count      = local.is_import ? 0 : 1
  name       = "${local.cluster_identifier}-subnet-group"
  subnet_ids = var.inputs.vpc_details.attributes.private_subnet_ids

  tags = merge(var.environment.cloud_tags, {
    Name = "${local.cluster_identifier}-subnet-group"
  })

  lifecycle {
    prevent_destroy = false # Disabled for testing
  }
}

# Create security group for Aurora cluster (skip if importing)
resource "aws_security_group" "aurora" {
  count       = local.is_import ? 0 : 1
  name_prefix = "${local.cluster_identifier}-"
  vpc_id      = var.inputs.vpc_details.attributes.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.environment.cloud_tags, {
    Name = "${local.cluster_identifier}-sg"
  })

  lifecycle {
    prevent_destroy = false # Disabled for testing
  }
}

# Get VPC CIDR block
data "aws_vpc" "selected" {
  id = var.inputs.vpc_details.attributes.vpc_id
}

# Create Aurora cluster
resource "aws_rds_cluster" "aurora" {
  cluster_identifier = local.cluster_identifier
  engine             = "aurora-postgresql"

  # When restoring from snapshot or importing, these fields must be same or ignored
  engine_version  = var.instance.spec.version_config.engine_version
  database_name   = var.instance.spec.version_config.database_name
  master_username = local.master_username
  master_password = local.master_password

  # Backup configuration
  backup_retention_period      = 7 # Hardcoded - 7 days retention
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  # Network and security - use existing resources when importing
  db_subnet_group_name   = local.is_import ? null : (length(aws_db_subnet_group.aurora) > 0 ? aws_db_subnet_group.aurora[0].name : null)
  vpc_security_group_ids = local.is_import ? null : (length(aws_security_group.aurora) > 0 ? [aws_security_group.aurora[0].id] : null)
  storage_encrypted      = true # Always enabled

  # Testing configurations
  skip_final_snapshot = true  # For testing
  deletion_protection = false # Disabled for testing

  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration {
    max_capacity = var.instance.spec.sizing.max_capacity
    min_capacity = var.instance.spec.sizing.min_capacity
  }

  # Restore from manual snapshot if specified
  # This is the KEY parameter that tells AWS to restore from snapshot instead of creating fresh
  snapshot_identifier = local.restore_from_backup ? var.instance.spec.restore_config.source_snapshot_identifier : null

  tags = merge(var.environment.cloud_tags, {
    Name = local.cluster_identifier
  })

  lifecycle {
    prevent_destroy = false # Disabled for testing

    # Ignore changes that would cause replacement when importing
    # Note: Can't use conditional here, so we always ignore these for safety
    ignore_changes = [
      engine_version,
      database_name,
      master_username,
      master_password,
      db_subnet_group_name,
      vpc_security_group_ids
    ]
  }
}

# Create Aurora cluster instances (writer + readers)
resource "aws_rds_cluster_instance" "aurora_writer" {
  count = 1
  # Use imported identifier if provided, otherwise generate new one
  identifier         = local.imported_writer_id != null ? local.imported_writer_id : "${var.instance_name}-${var.environment.unique_name}-writer"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.instance.spec.sizing.instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  performance_insights_enabled = true
  monitoring_interval          = 0 # Disabled to avoid IAM role requirement

  tags = merge(var.environment.cloud_tags, {
    Name = local.imported_writer_id != null ? local.imported_writer_id : "${var.instance_name}-${var.environment.unique_name}-writer"
    Role = "writer"
  })

  lifecycle {
    prevent_destroy = false # Disabled for testing
    ignore_changes = [
      identifier # Don't change the imported identifier
    ]
  }
}

# Create/Import read replica instances
resource "aws_rds_cluster_instance" "aurora_readers" {
  count = var.instance.spec.sizing.read_replica_count

  # For imports: use existing identifiers for imported instances, generate new ones for additional instances
  # For new deployments: generate new identifiers for all instances
  identifier = (
    local.is_import && count.index < length(local.reader_instance_ids)
    ? local.reader_instance_ids[count.index]
    : "${var.instance_name}-${var.environment.unique_name}-reader-${count.index + 1}"
  )

  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.instance.spec.sizing.instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  performance_insights_enabled = true
  monitoring_interval          = 0 # Disabled to avoid IAM role requirement

  tags = merge(var.environment.cloud_tags, {
    Name = (
      local.is_import && count.index < length(local.reader_instance_ids)
      ? local.reader_instance_ids[count.index]
      : "${var.instance_name}-${var.environment.unique_name}-reader-${count.index + 1}"
    )
    Role = "reader"
  })

  lifecycle {
    prevent_destroy = false # Disabled for testing
    ignore_changes = [
      identifier # Don't change the identifier after creation/import
    ]
  }
}

# Password management - using random password generation only
# The password is stored in Terraform state and accessible via output interfaces
# For production use, consider external secret management solutions
