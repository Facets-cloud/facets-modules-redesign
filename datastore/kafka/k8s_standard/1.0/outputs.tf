locals {
  output_attributes = {
    namespace         = local.namespace
    cluster_name      = var.instance_name
    bootstrap_service = local.bootstrap_service
    bootstrap_servers = "${local.bootstrap_service}.${local.namespace}.svc.cluster.local:9092"
    replica_count     = local.replica_count
    broker_endpoints  = local.broker_endpoints
    kafka_version     = local.kafka_version
    admin_username    = local.admin_username
    admin_password    = sensitive(random_password.kafka_admin_password.result)
    ca_cert_secret    = "${var.instance_name}-cluster-ca-cert"
    secrets           = ["admin_password"]
  }

  output_interfaces = {
    bootstrap = {
      host           = "${local.bootstrap_service}.${local.namespace}.svc.cluster.local"
      port           = 9092
      username       = local.admin_username
      password       = random_password.kafka_admin_password.result
      sasl_mechanism = "SCRAM-SHA-512"
    }
    bootstrap_tls = local.tls_enabled ? {
      host           = "${local.bootstrap_service}.${local.namespace}.svc.cluster.local"
      port           = 9093
      username       = local.admin_username
      password       = random_password.kafka_admin_password.result
      sasl_mechanism = "SCRAM-SHA-512"
      ca_cert_secret = "${var.instance_name}-cluster-ca-cert"
    } : null
  }
}
