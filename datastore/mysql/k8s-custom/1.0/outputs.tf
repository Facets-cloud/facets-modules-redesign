locals {
  output_attributes = {
    port             = local.mysql_port
    password         = local.root_password
    username         = "\"root\""
    namespace        = local.namespace
    pvc_names        = ["mysql-data-${local.statefulset_name}-0"]
    secret_name      = kubernetes_secret.mysql_secret.metadata[0].name
    service_name     = kubernetes_service.mysql_service.metadata[0].name
    storage_size     = local.storage_size
    database_name    = local.database_name
    mysql_version    = local.mysql_version
    replica_count    = local.replica_count
    configmap_name   = kubernetes_config_map.mysql_init.metadata[0].name
    reader_endpoint  = local.reader_endpoint
    primary_endpoint = local.primary_endpoint
    statefulset_name = kubernetes_stateful_set.mysql.metadata[0].name
  }
  output_interfaces = {
    reader = {
      host              = local.reader_endpoint
      name              = local.database_name
      port              = tostring(local.mysql_port)
      password          = local.root_password
      username          = "\"root\""
      connection_string = local.reader_connection_string
    }
    writer = {
      host              = local.primary_endpoint
      name              = local.database_name
      port              = tostring(local.mysql_port)
      password          = local.root_password
      username          = "\"root\""
      connection_string = local.writer_connection_string
    }
  }
}