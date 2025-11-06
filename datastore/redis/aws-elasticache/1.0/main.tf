# Generate secure auth token for Redis (only for new clusters)
resource "random_password" "redis_auth_token" {
  count   = var.instance.spec.imports.cluster_id != null && var.instance.spec.imports.cluster_id != "" ? 0 : 1
  length  = 64
  special = false
}

# ElastiCache subnet group
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.instance_name}-${var.environment.unique_name}"
  subnet_ids = var.inputs.vpc_details.attributes.private_subnet_ids

  tags = merge(
    var.environment.cloud_tags,
    {
      Name = "${var.instance_name}-${var.environment.unique_name}-subnet-group"
    }
  )

  lifecycle {
    ignore_changes = [
      # Ignore name changes for imported resources
      name,
    ]
  }
}

# Security group for ElastiCache
resource "aws_security_group" "redis" {
  name_prefix = "${var.instance_name}-${var.environment.unique_name}-"
  vpc_id      = var.inputs.vpc_details.attributes.vpc_id

  # Allow Redis traffic from within VPC
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.inputs.vpc_details.attributes.vpc_cidr_block]
    description = "Redis traffic from VPC"
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(
    var.environment.cloud_tags,
    {
      Name = "${var.instance_name}-${var.environment.unique_name}-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      # Ignore name_prefix changes for imported resources
      name_prefix,
      name,
    ]
  }
}

# Local values for high availability logic
locals {
  # Ensure we have at least 2 nodes if we want high availability
  # If user specifies 1 node, disable automatic failover for single-node setup
  enable_ha             = var.instance.spec.sizing.num_cache_nodes >= 2
  actual_cache_clusters = var.instance.spec.sizing.num_cache_nodes
}

# ElastiCache replication group (cluster mode disabled for simplicity)
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = local.cluster_id
  description          = "Redis cluster for ${var.instance_name}"

  # Basic configuration
  node_type            = var.instance.spec.version_config.node_type
  port                 = 6379
  parameter_group_name = var.instance.spec.sizing.parameter_group_name
  engine_version       = var.instance.spec.version_config.redis_version

  # Cluster configuration - ensure compatibility with HA settings
  num_cache_clusters = local.actual_cache_clusters

  # Network and security
  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]

  # Security settings (hardcoded for security)
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  # Only set auth_token for new clusters, not for imported ones
  auth_token                 = var.instance.spec.imports.cluster_id != null && var.instance.spec.imports.cluster_id != "" ? var.instance.spec.imports.auth_token : random_password.redis_auth_token[0].result
  auth_token_update_strategy = var.instance.spec.imports.cluster_id != null && var.instance.spec.imports.cluster_id != "" ? null : "ROTATE"

  # High availability - only enable if we have multiple nodes
  multi_az_enabled           = local.enable_ha
  automatic_failover_enabled = local.enable_ha

  # Backup settings (hardcoded for data protection)
  snapshot_retention_limit = var.instance.spec.sizing.snapshot_retention_limit
  snapshot_window          = "03:00-05:00"
  maintenance_window       = "sun:05:00-sun:07:00"

  # Auto minor version upgrade for security patches
  auto_minor_version_upgrade = true

  # Apply immediately for critical updates
  apply_immediately = false

  # Handle restoration from snapshot
  snapshot_name = var.instance.spec.restore_config.restore_from_snapshot ? var.instance.spec.restore_config.snapshot_name : null

  tags = merge(
    var.environment.cloud_tags,
    {
      Name = "${var.instance_name}-${var.environment.unique_name}"
    }
  )

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      # Ignore changes to snapshot_name after initial creation
      snapshot_name,
      # Ignore replication group ID changes for imported resources
      replication_group_id,
      # Ignore ALL auth-related fields for imported resources
      auth_token,
      auth_token_update_strategy,
    ]
  }

  depends_on = [
    aws_elasticache_subnet_group.redis,
    aws_security_group.redis
  ]
}