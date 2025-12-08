locals {
  output_attributes = {}
  output_interfaces = {
    cluster = {
      endpoint          = google_managed_kafka_cluster.main.bootstrap_servers
      connection_string = "kafka://${google_managed_kafka_cluster.main.bootstrap_servers}"
      username          = ""
      password          = ""
      endpoints         = { for idx, broker in split(",", google_managed_kafka_cluster.main.bootstrap_servers) : tostring(idx) => broker }
      secrets           = ["password", "connection_string"]
    }
  }
}
