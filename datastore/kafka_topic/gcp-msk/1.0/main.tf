# GCP Managed Kafka Topic
# Creates and manages topics for GCP Managed Service for Apache Kafka

resource "google_managed_kafka_topic" "main" {
  topic_id           = var.instance_name # Using instance_name as topic_id
  cluster            = var.inputs.kafka_cluster.attributes.cluster_id
  location           = var.inputs.kafka_cluster.attributes.location
  replication_factor = var.instance.spec.replication_factor
  partition_count    = var.instance.spec.partition_count

  # Topic-specific Kafka configurations
  # Users can pass any Kafka topic configuration as key-value pairs
  # Examples: cleanup.policy, compression.type, retention.ms, max.message.bytes, etc.
  configs = var.instance.spec.configs

  lifecycle {
    # Partition count can only be increased, not decreased
    ignore_changes = []
  }
}
