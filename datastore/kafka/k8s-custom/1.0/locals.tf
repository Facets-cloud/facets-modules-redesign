locals {
  # Generate broker endpoints for cluster connection
  # For single broker setup, use simpler endpoint structure
  broker_endpoints = [
    for i in range(1) : # Single broker for test environment
    "${local.release_name}-broker-${i}.${local.release_name}-broker-headless.${local.namespace}.svc.cluster.local:9092"
  ]

  # Main service endpoint for client connections
  cluster_endpoint = "${local.release_name}.${local.namespace}.svc.cluster.local:9092"

  # Connection string for Kafka clients
  connection_string = "kafka://${local.kafka_user}:${local.kafka_password}@${local.cluster_endpoint}"

  # Cluster endpoint with all brokers
  full_cluster_endpoint = join(",", local.broker_endpoints)
}