locals {
  output_attributes = {
    connector_id       = google_managed_kafka_connector.main.connector_id
    connector_name     = google_managed_kafka_connector.main.name
    connect_cluster_id = google_managed_kafka_connector.main.connect_cluster
    location           = google_managed_kafka_connector.main.location
    state              = google_managed_kafka_connector.main.state
    configs            = google_managed_kafka_connector.main.configs
  }
  output_interfaces = {
  }
}