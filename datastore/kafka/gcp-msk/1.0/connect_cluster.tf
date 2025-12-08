# GCP Managed Kafka Connect Cluster
# Conditionally created when connect_cluster is true

locals {
  connect_enabled = try(var.instance.spec.connect_cluster, false)

  # Default configuration for Connect cluster
  connect_cluster_id   = "${local.cluster_name}-connect"
  connect_vcpu_count   = 12          # Default: 12 vCPUs
  connect_memory_bytes = 21474836480 # Default: 20 GB (20 * 1024^3)

  #######################################################################
  # DNS domain name for Kafka cluster visibility
  # This makes the Kafka cluster's DNS name resolvable from the Connect cluster workers
  # 
  # Why this is needed:
  #   - Allows Connect workers to resolve and connect to the Kafka cluster using DNS
  #   - Required for MirrorMaker2 connectors (cluster-to-cluster replication)
  #   - Enables connectors that need direct access to Kafka topics
  #   - Ensures proper service discovery within the VPC network
  # 
  # Format: {cluster_id}.{region}.managedkafka.{project_id}.cloud.goog
  # Example: my-cluster.us-central1.managedkafka.my-project.cloud.goog
  # 
  # Reference: https://cloud.google.com/managed-kafka/docs/connect-cluster
  #
  #######################################################################


  # DNS domain for MirrorMaker2 and other connectors
  kafka_dns_domain = "${google_managed_kafka_cluster.main.cluster_id}.${local.region}.managedkafka.${local.project_id}.cloud.goog"
}

resource "google_managed_kafka_connect_cluster" "main" {
  count = local.connect_enabled ? 1 : 0

  connect_cluster_id = local.connect_cluster_id
  kafka_cluster      = "projects/${local.project_id}/locations/${local.region}/clusters/${google_managed_kafka_cluster.main.cluster_id}"
  location           = local.region

  capacity_config {
    vcpu_count   = local.connect_vcpu_count
    memory_bytes = local.connect_memory_bytes
  }

  gcp_config {
    access_config {
      network_configs {
        primary_subnet = var.inputs.vpc_network.attributes.private_subnet_id

        # DNS domain names for Kafka cluster visibility
        dns_domain_names = [local.kafka_dns_domain]
      }
    }
  }

  labels = merge(local.common_labels, {
    connect_cluster = "enabled"
  })

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_managed_kafka_cluster.main]
}
