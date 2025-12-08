locals {
  output_attributes = {
    cluster_id = google_managed_kafka_cluster.main.cluster_id
    location   = google_managed_kafka_cluster.main.location
    cluster_name = local.cluster_name
    kafka_version = local.kafka_version
  }
  output_interfaces = {}
}
