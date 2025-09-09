# Generate a random password only when NOT restoring from backup
# Excludes characters not allowed by Aurora MySQL: '/', '@', '"', ' ' (space)
resource "random_password" "master_password" {
  count            = var.instance.spec.restore_config.restore_from_backup ? 0 : 1
  length           = 16
  special          = true
  override_special = "!#$%&*+-=?^_`{|}~" # Safe special characters for Aurora MySQL
}

# Generate unique cluster identifier
locals {
  cluster_identifier  = "${var.instance_name}-${var.environment.unique_name}"
  restore_from_backup = var.instance.spec.restore_config.restore_from_backup
  source_snapshot_id  = var.instance.spec.restore_config.source_snapshot_identifier
  master_password     = local.restore_from_backup ? var.instance.spec.restore_config.master_password : random_password.master_password[0].result
  master_username     = local.restore_from_backup ? var.instance.spec.restore_config.master_username : "admin"

  # Split reader instance identifiers if provided for import
  reader_instance_ids = try(var.instance.spec.imports.reader_instance_identifiers, null) != null && var.instance.spec.imports.reader_instance_identifiers != "" ? split(",", trimspace(var.instance.spec.imports.reader_instance_identifiers)) : []
}

# Create DB subnet group
resource "aws_db_subnet_group" "aurora" {
  name       = "${local.cluster_identifier}-subnet-group"
  subnet_ids = var.inputs.vpc_details.attributes.private_subnet_ids

  tags = merge(var.environment.cloud_tags, {
    Name = "${local.cluster_identifier}-subnet-group"
  })

  lifecycle {
    prevent_destroy = false # Disabled for testing
  }
}

# Create security group for Aurora cluster
resource "aws_security_group" "aurora" {
  name_prefix = "${local.cluster_identifier}-"
  vpc_id      = var.inputs.vpc_details.attributes.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
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
  engine             = "aurora-mysql"

  # When restoring from snapshot, these fields must be completely omitted (null)
  # AWS will inherit these values from the snapshot automatically
  engine_version  = local.restore_from_backup ? null : var.instance.spec.version_config.engine_version
  database_name   = local.restore_from_backup ? null : var.instance.spec.version_config.database_name
  master_username = local.restore_from_backup ? null : local.master_username
  master_password = local.restore_from_backup ? null : local.master_password

  # Backup configuration
  backup_retention_period      = 7 # Hardcoded - 7 days retention
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  # Network and security
  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = [aws_security_group.aurora.id]
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
  }
}

# Create Aurora cluster instances (writer + readers)
resource "aws_rds_cluster_instance" "aurora_writer" {
  count              = 1
  identifier         = "${local.cluster_identifier}-writer"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.instance.spec.sizing.instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  performance_insights_enabled = true
  monitoring_interval          = 0 # Disabled to avoid IAM role requirement

  tags = merge(var.environment.cloud_tags, {
    Name = "${local.cluster_identifier}-writer"
    Role = "writer"
  })

  lifecycle {
    prevent_destroy = false # Disabled for testing
  }
}

# Create read replica instances
resource "aws_rds_cluster_instance" "aurora_readers" {
  count              = var.instance.spec.sizing.read_replica_count
  identifier         = "${local.cluster_identifier}-reader-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = var.instance.spec.sizing.instance_class
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  performance_insights_enabled = true
  monitoring_interval          = 0 # Disabled to avoid IAM role requirement

  tags = merge(var.environment.cloud_tags, {
    Name = "${local.cluster_identifier}-reader-${count.index + 1}"
    Role = "reader"
  })

  lifecycle {
    prevent_destroy = false # Disabled for testing
  }
}

# Password management - using random password generation only
# The password is stored in Terraform state and accessible via output interfaces
# For production use, consider external secret management solutions