locals {
  # Full SCRAM username (KafkaUser resource name)
  scram_username = "${var.instance_name}-${local.admin_username}"

  output_attributes = {
    namespace         = local.namespace
    cluster_name      = var.instance_name
    bootstrap_service = local.bootstrap_service
    bootstrap_servers = "${local.bootstrap_service}.${local.namespace}.svc.cluster.local:9092"
    replica_count     = local.replica_count
    broker_endpoints  = local.broker_endpoints
    kafka_version     = local.kafka_version
    admin_username    = local.scram_username
    admin_password    = random_password.kafka_admin_password.result
    ca_cert_secret    = "${var.instance_name}-cluster-ca-cert"
    secrets           = ["bootstrap_servers", "admin_password", "broker_endpoints"]
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
