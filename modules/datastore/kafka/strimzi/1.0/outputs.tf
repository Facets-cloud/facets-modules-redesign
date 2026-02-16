locals {
  # Full SCRAM username (KafkaUser resource name)
  scram_username = "${var.instance_name}-${local.admin_username}"

  output_attributes = {
    cluster_name      = var.instance_name
    kafka_version     = local.kafka_version
  }

  output_interfaces = {
    cluster = {
      endpoint          = "${local.bootstrap_service}.${local.namespace}.svc.cluster.local:9092"
      connection_string = "kafka://${local.scram_username}:${random_password.kafka_admin_password.result}@${local.bootstrap_service}.${local.namespace}.svc.cluster.local:9092"
      username          = local.scram_username
      password          = random_password.kafka_admin_password.result
      endpoints = {
        for i in range(local.replica_count) :
        tostring(i) => "${var.instance_name}-${local.node_pool_name}-${i}.${var.instance_name}-kafka-brokers.${local.namespace}.svc.cluster.local:9092"
      }
      secrets = ["connection_string", "password", "endpoint"]
    }
  }
}
