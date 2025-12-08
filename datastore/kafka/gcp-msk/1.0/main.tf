# KMS key ring for encryption
resource "google_kms_key_ring" "kafka" {
  name     = "${local.cluster_name}-keyring"
  location = local.region

  lifecycle {
    prevent_destroy = true
  }
}

# KMS crypto key for encryption
resource "google_kms_crypto_key" "kafka" {
  name            = "${local.cluster_name}-key"
  key_ring        = google_kms_key_ring.kafka.id
  rotation_period = "7776000s" # 90 days

  labels = merge(local.common_labels, {
    purpose = "kafka-encryption"
  })

  lifecycle {
    prevent_destroy = true
  }
}

# GCP Managed Kafka Cluster
resource "google_managed_kafka_cluster" "main" {
  cluster_id = local.cluster_name
  location   = local.region

  capacity_config {
    vcpu_count   = local.vcpu_count
    memory_bytes = local.memory_bytes
  }

  gcp_config {
    access_config {
      network_configs {
        subnet = var.inputs.vpc_network.attributes.subnet_id
      }
    }

    # KMS encryption configuration
    kms_key = google_kms_crypto_key.kafka.id
  }

  # Replication configuration for multi-zone deployment
  replication_config {
    region_configs {
      region = local.region

      # Create broker configs for each availability zone
      dynamic "broker_config" {
        for_each = toset(local.availability_zones)
        content {
          # Zone-specific configuration
          # GCP will automatically distribute brokers across zones
        }
      }
    }
  }

  # Rebalance configuration for automatic scaling
  rebalance_config {
    mode = "AUTO_REBALANCE_ON_SCALE_UP"
  }

  labels = local.common_labels

  lifecycle {
    prevent_destroy = true
  }
}
