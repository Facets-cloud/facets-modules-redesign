# KMS key for encryption (only for new clusters, not imported)
resource "aws_kms_key" "msk" {
  count       = local.is_import ? 0 : 1
  description = "KMS key for MSK cluster ${local.cluster_name}"

  tags = merge(local.common_tags, {
    Purpose = "MSK Encryption"
  })
}

resource "aws_kms_alias" "msk" {
  count         = local.is_import ? 0 : 1
  name          = "alias/msk-${local.cluster_name}"
  target_key_id = aws_kms_key.msk[0].key_id
}

# Security group for MSK cluster (only for new clusters, not imported)
resource "aws_security_group" "msk_cluster" {
  count       = local.is_import ? 0 : 1
  name_prefix = "${local.cluster_name}-msk-"
  vpc_id      = var.inputs.vpc_details.attributes.vpc_id
  description = "Security group for MSK cluster ${local.cluster_name}"

  # Kafka broker communication
  ingress {
    from_port   = 9092
    to_port     = 9098
    protocol    = "tcp"
    cidr_blocks = [var.inputs.vpc_details.attributes.vpc_cidr_block]
    description = "Kafka broker communication"
  }

  # Zookeeper communication
  ingress {
    from_port   = 2181
    to_port     = 2181
    protocol    = "tcp"
    cidr_blocks = [var.inputs.vpc_details.attributes.vpc_cidr_block]
    description = "Zookeeper communication"
  }

  # JMX monitoring
  ingress {
    from_port   = 11001
    to_port     = 11002
    protocol    = "tcp"
    cidr_blocks = [var.inputs.vpc_details.attributes.vpc_cidr_block]
    description = "JMX monitoring"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Purpose = "MSK Security Group"
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      # Ignore name changes for imported resources
      name_prefix,
      name,
    ]
  }
}

# CloudWatch log group for MSK logs (only for new clusters)
resource "aws_cloudwatch_log_group" "msk_logs" {
  count             = local.is_import ? 0 : 1
  name              = "/aws/msk/${local.cluster_name}"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Purpose = "MSK Logs"
  })
}

# MSK Configuration (only for new clusters)
resource "aws_msk_configuration" "main" {
  count          = local.is_import ? 0 : 1
  kafka_versions = [local.kafka_version]
  name           = "${local.cluster_name}-config"
  description    = "MSK configuration for ${local.cluster_name}"

  server_properties = <<PROPERTIES
auto.create.topics.enable=false
default.replication.factor=3
min.insync.replicas=2
num.partitions=3
num.replica.fetchers=2
replica.lag.time.max.ms=30000
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
socket.send.buffer.bytes=102400
unclean.leader.election.enable=false
zookeeper.session.timeout.ms=18000
PROPERTIES
}

# MSK Cluster
# Note: Version 2.8.1 may not be available in all AWS regions
# Recommended to use versions 3.4.0+ for better region compatibility
resource "aws_msk_cluster" "main" {
  cluster_name           = local.cluster_name
  kafka_version          = local.kafka_version
  number_of_broker_nodes = var.instance.spec.sizing.number_of_broker_nodes

  broker_node_group_info {
    instance_type   = local.instance_type
    client_subnets  = local.client_subnet_ids
    security_groups = [local.security_group_id]

    storage_info {
      ebs_storage_info {
        volume_size = var.instance.spec.sizing.volume_size
      }
    }
  }

  # Only apply configuration for new clusters
  dynamic "configuration_info" {
    for_each = local.is_import ? [] : [1]
    content {
      arn      = aws_msk_configuration.main[0].arn
      revision = aws_msk_configuration.main[0].latest_revision
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  # Only configure logging for new clusters
  dynamic "logging_info" {
    for_each = local.is_import ? [] : [1]
    content {
      broker_logs {
        cloudwatch_logs {
          enabled   = true
          log_group = aws_cloudwatch_log_group.msk_logs[0].name
        }
        firehose {
          enabled = false
        }
        s3 {
          enabled = false
        }
      }
    }
  }

  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      # Ignore name changes for imported resources
      cluster_name,
      # Ignore configuration changes for imported resources
      configuration_info,
      # Ignore version changes for imported resources (must be updated through AWS API)
      kafka_version,
      # Ignore logging changes for imported resources
      logging_info,
      # Ignore encryption changes for imported resources
      encryption_info,
      # Ignore monitoring changes for imported resources
      open_monitoring,
      # Ignore broker node group changes for imported resources
      broker_node_group_info,
      # Ignore number of broker nodes for imported resources
      number_of_broker_nodes,
    ]
  }
}