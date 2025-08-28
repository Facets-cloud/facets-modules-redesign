# main.tf - DocumentDB Cluster Implementation

# Random password generation for new clusters (when not restoring)
resource "random_password" "master" {
  count   = var.instance.spec.restore_config.restore_from_snapshot ? 0 : 1
  length  = 16
  special = true
}

# DocumentDB Subnet Group
resource "aws_docdb_subnet_group" "main" {
  name       = "${var.instance_name}-${var.environment.unique_name}"
  subnet_ids = var.inputs.vpc_details.attributes.private_subnet_ids

  tags = merge(var.environment.cloud_tags, {
    Name = "${var.instance_name}-${var.environment.unique_name}"
  })
}

# Security Group for DocumentDB
resource "aws_security_group" "documentdb" {
  name_prefix = "${var.instance_name}-${var.environment.unique_name}-"
  vpc_id      = var.inputs.vpc_details.attributes.vpc_id

  ingress {
    from_port   = var.instance.spec.version_config.port
    to_port     = var.instance.spec.version_config.port
    protocol    = "tcp"
    cidr_blocks = [var.inputs.vpc_details.attributes.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.environment.cloud_tags, {
    Name = "${var.instance_name}-${var.environment.unique_name}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# DocumentDB Cluster Parameter Group
resource "aws_docdb_cluster_parameter_group" "main" {
  family = var.instance.spec.version_config.engine_version == "6.0.0" || var.instance.spec.version_config.engine_version == "5.0.0" ? "docdb5.0" : "docdb4.0"
  name   = "${var.instance_name}-${var.environment.unique_name}"

  parameter {
    name  = "tls"
    value = "enabled"
  }

  tags = merge(var.environment.cloud_tags, {
    Name = "${var.instance_name}-${var.environment.unique_name}"
  })
}

# DocumentDB Cluster
resource "aws_docdb_cluster" "main" {
  cluster_identifier        = "${var.instance_name}-${var.environment.unique_name}"
  engine                    = "docdb"
  engine_version            = var.instance.spec.version_config.engine_version == "6.0.0" ? "5.0.0" : var.instance.spec.version_config.engine_version
  master_username           = var.instance.spec.restore_config.restore_from_snapshot ? var.instance.spec.restore_config.master_username : "docdbadmin"
  master_password           = var.instance.spec.restore_config.restore_from_snapshot ? var.instance.spec.restore_config.master_password : random_password.master[0].result
  port                      = var.instance.spec.version_config.port
  backup_retention_period   = 7
  preferred_backup_window   = "07:00-09:00"
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.instance_name}-${var.environment.unique_name}-final-snapshot"

  # Restore configuration
  snapshot_identifier = var.instance.spec.restore_config.restore_from_snapshot ? var.instance.spec.restore_config.snapshot_identifier : null

  # Network configuration
  db_subnet_group_name   = aws_docdb_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.documentdb.id]

  # Parameter group
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name

  # Security settings
  storage_encrypted = true

  tags = merge(var.environment.cloud_tags, {
    Name = "${var.instance_name}-${var.environment.unique_name}"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      # Prevent recreation for these attributes that would require delete/recreate
      db_subnet_group_name,
      vpc_security_group_ids
    ]
  }
}

# DocumentDB Cluster Instances
resource "aws_docdb_cluster_instance" "cluster_instances" {
  count              = var.instance.spec.sizing.instance_count
  identifier         = "${var.instance_name}-${var.environment.unique_name}-${count.index}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.instance.spec.sizing.instance_class

  tags = merge(var.environment.cloud_tags, {
    Name = "${var.instance_name}-${var.environment.unique_name}-${count.index}"
  })

  lifecycle {
    prevent_destroy = true
  }
}