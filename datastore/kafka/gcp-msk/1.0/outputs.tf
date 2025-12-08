locals {
  output_attributes = {
    cluster_id               = google_managed_kafka_cluster.main.cluster_id
    location                 = google_managed_kafka_cluster.main.location
    cluster_name             = local.cluster_name
    connect_cluster_id       = local.connect_enabled ? google_managed_kafka_connect_cluster.main[0].connect_cluster_id : null
    connect_cluster_location = local.connect_enabled ? google_managed_kafka_connect_cluster.main[0].location : null
    connect_cluster_state    = local.connect_enabled ? google_managed_kafka_connect_cluster.main[0].state : null
    kafka_version            = local.kafka_version
  }
  output_interfaces = {}
}
