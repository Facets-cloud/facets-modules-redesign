locals {
  output_attributes = {
    port             = local.mongodb_port
    password         = local.root_password
    username         = "\"root\""
    namespace        = local.namespace
    pvc_names        = ["mongodb-data-${local.statefulset_name}-0"]
    secret_name      = kubernetes_secret.mongodb_secret.metadata[0].name
    service_name     = kubernetes_service.mongodb_service.metadata[0].name
    storage_size     = local.storage_size
    database_name    = local.database_name
    mongo_version    = local.mongo_version
    replica_count    = local.replica_count
    configmap_name   = kubernetes_config_map.mongodb_init.metadata[0].name
    reader_endpoint  = local.reader_endpoint
    primary_endpoint = local.primary_endpoint
    statefulset_name = kubernetes_stateful_set.mongodb.metadata[0].name
  }
  output_interfaces = {
    writer = {
      host              = local.primary_endpoint
      name              = local.database_name
      port              = tostring(local.mongodb_port)
      password          = local.root_password
      username          = "\"root\""
      connection_string = local.writer_connection_string
    }
    reader = {
      host              = local.reader_endpoint
      name              = local.database_name
      port              = tostring(local.mongodb_port)
      password          = local.root_password
      username          = "\"root\""
      connection_string = local.reader_connection_string
    }
    cluster = {
      endpoint          = "${local.primary_endpoint}:${local.mongodb_port}"
      username          = "\"root\""
      password          = local.root_password
      connection_string = local.writer_connection_string
    }
  }
}