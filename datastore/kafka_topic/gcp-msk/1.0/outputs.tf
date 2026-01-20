locals {
  output_attributes = {
    topic_id           = google_managed_kafka_topic.main.topic_id
    topic_name         = google_managed_kafka_topic.main.name
    partition_count    = google_managed_kafka_topic.main.partition_count
    replication_factor = google_managed_kafka_topic.main.replication_factor
    cluster_id         = google_managed_kafka_topic.main.cluster
    location           = google_managed_kafka_topic.main.location
    configs            = google_managed_kafka_topic.main.configs
  }
  output_interfaces = {
  }
}