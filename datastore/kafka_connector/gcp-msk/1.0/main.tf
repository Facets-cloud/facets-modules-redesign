# GCP Managed Kafka Connector
# Creates and manages Kafka Connect connectors for data integration

locals {
  # Auto-generate connector_id from instance_name and environment
  connector_id = "${var.instance_name}-${var.environment.unique_name}"
}

resource "google_managed_kafka_connector" "main" {
  connector_id    = local.connector_id
  connect_cluster = var.inputs.kafka_cluster.attributes.connect_cluster_id
  location        = var.inputs.kafka_cluster.attributes.connect_cluster_location

  # Connector configurations
  # Users can pass any Kafka connector configuration as key-value pairs
  # Required keys: connector.class, tasks.max, topics
  # Examples: connector.class, tasks.max, topics, key.converter, value.converter, etc.
  configs = var.instance.spec.configs

  # Optional task restart policy for failed connectors/tasks
  dynamic "task_restart_policy" {
    for_each = var.instance.spec.task_restart_policy != null ? [var.instance.spec.task_restart_policy] : []
    content {
      minimum_backoff = task_restart_policy.value.minimum_backoff
      maximum_backoff = task_restart_policy.value.maximum_backoff
    }
  }
}
