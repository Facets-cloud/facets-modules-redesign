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

# Generate random password for master user (only if not restoring)
resource "random_password" "master_password" {
  count   = local.is_restore_operation ? 0 : 1
  length  = 16
  special = true
}

# Store password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "mysql_password" {
  name        = local.secret_name
  description = "MySQL master password for ${var.instance_name}"

  tags = merge(var.environment.cloud_tags, {
    Name   = local.secret_name
    Module = "mysql"
    Flavor = "aws-rds"
  })
}

resource "aws_secretsmanager_secret_version" "mysql_password" {
  secret_id = aws_secretsmanager_secret.mysql_password.id
  secret_string = jsonencode({
    username = local.master_username
    password = local.master_password
  })
}

# Create DB subnet group
resource "aws_db_subnet_group" "mysql" {
  name       = local.subnet_group_name
  subnet_ids = var.inputs.vpc_details.attributes.private_subnet_ids

  tags = merge(var.environment.cloud_tags, {
    Name   = local.subnet_group_name
    Module = "mysql"
    Flavor = "aws-rds"
  })
}

# Create security group for MySQL
resource "aws_security_group" "mysql" {
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
}

# Create the MySQL RDS instance (new instance)
resource "aws_db_instance" "mysql" {
  count = local.is_restore_operation ? 0 : 1

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
  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.mysql.id]
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

  # Lifecycle management
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      password,                 # Managed by secrets manager
      final_snapshot_identifier # Timestamp will always change
    ]
  }

  tags = merge(var.environment.cloud_tags, {
    Name   = local.db_identifier
    Module = "mysql"
    Flavor = "aws-rds"
  })
}

# Create the MySQL RDS instance (restored from backup)
resource "aws_db_instance" "mysql_restored" {
  count = local.is_restore_operation ? 1 : 0

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
  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.mysql.id]
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
      password,                 # Managed by secrets manager
      final_snapshot_identifier # Timestamp will always change
    ]
  }

  tags = merge(var.environment.cloud_tags, {
    Name   = local.db_identifier
    Module = "mysql"
    Flavor = "aws-rds"
  })
}

# Local to get the actual instance (either new or restored)
locals {
  mysql_instance = local.is_restore_operation ? aws_db_instance.mysql_restored[0] : aws_db_instance.mysql[0]
}

# Create read replicas if requested
resource "aws_db_instance" "read_replicas" {
  count = var.instance.spec.sizing.read_replica_count

  # Basic configuration
  identifier          = "${local.db_identifier}-replica-${count.index + 1}"
  replicate_source_db = local.mysql_instance.identifier

  # Instance configuration (same as master for consistency)
  instance_class = var.instance.spec.sizing.instance_class
  storage_type   = var.instance.spec.sizing.storage_type

  # Network configuration (same security group)
  vpc_security_group_ids = [aws_security_group.mysql.id]
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
  }

  tags = merge(var.environment.cloud_tags, {
    Name   = "${local.db_identifier}-replica-${count.index + 1}"
    Module = "mysql"
    Flavor = "aws-rds"
    Role   = "read-replica"
  })
}