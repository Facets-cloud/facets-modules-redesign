locals {
  output_attributes = {
    version             = local.kafka_version
    cpu_limit           = local.cpu_limit
    namespace           = local.namespace
    cluster_size        = local.cluster_size
    memory_limit        = local.memory_limit
    service_name        = local.service_name
    storage_size        = local.storage_size
    auth_secret_name    = kubernetes_secret.kafka_auth.metadata[0].name
    broker_endpoints    = local.broker_endpoints
    helm_release_name   = helm_release.kafka.name
    persistence_enabled = local.enable_persistence
  }
  output_interfaces = {
    cluster = {
      endpoint          = local.full_cluster_endpoint
      password          = local.kafka_password
      username          = local.kafka_user
      endpoints         = { for i, endpoint in local.broker_endpoints : tostring(i) => endpoint }
      connection_string = local.connection_string
    }
  }
}