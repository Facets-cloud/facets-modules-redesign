# KMS key for encryption
resource "aws_kms_key" "msk" {
  description = "KMS key for MSK cluster ${local.cluster_name}"

  tags = merge(local.common_tags, {
    Purpose = "MSK Encryption"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "msk" {
  name          = "alias/msk-${local.cluster_name}"
  target_key_id = aws_kms_key.msk.key_id
}

# Security group for MSK cluster
resource "aws_security_group" "msk_cluster" {
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
  }
}

# CloudWatch log group for MSK logs
resource "aws_cloudwatch_log_group" "msk_logs" {
  name              = "/aws/msk/${local.cluster_name}"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Purpose = "MSK Logs"
  })
}

# MSK Configuration
resource "aws_msk_configuration" "main" {
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

  lifecycle {
    prevent_destroy = true
  }
}

# MSK Cluster
resource "aws_msk_cluster" "main" {
  cluster_name           = local.cluster_name
  kafka_version          = local.kafka_version
  number_of_broker_nodes = var.instance.spec.sizing.number_of_broker_nodes

  broker_node_group_info {
    instance_type   = local.instance_type
    client_subnets  = local.client_subnet_ids
    security_groups = [aws_security_group.msk_cluster.id]

    storage_info {
      ebs_storage_info {
        volume_size = var.instance.spec.sizing.volume_size
      }
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.main.arn
    revision = aws_msk_configuration.main.latest_revision
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

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk_logs.name
      }
      firehose {
        enabled = false
      }
      s3 {
        enabled = false
      }
    }
  }

  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}