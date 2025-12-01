locals {
  output_attributes = {
    cluster_name      = local.cluster_name
    namespace         = local.namespace
    mysql_version     = var.instance.spec.mysql_version
    mode              = var.instance.spec.mode
    replicas          = local.replicas
    resource_type     = "mysql"
    resource_name     = var.instance_name
    primary_service   = try(data.kubernetes_service.mysql_primary.metadata[0].name, "${local.cluster_name}-mysql")
    read_service      = local.reader_host != null ? try(kubernetes_service.mysql_read[0].metadata[0].name, null) : null
    connection_secret = try(data.kubernetes_secret.mysql_credentials.metadata[0].name, "${local.cluster_name}-conn-credential")
    pod_prefix = {
      writer = "${local.cluster_name}-mysql"
      reader = local.create_read_service ? "${local.cluster_name}-mysql-read" : null
    }
    selectors = {
      mysql = {
        "app.kubernetes.io/instance"   = local.cluster_name
        "app.kubernetes.io/managed-by" = "kubeblocks"
        "app.kubernetes.io/name"       = "mysql"
      }
    }
    defaultDatabase = local.mysql_database
  }
  output_interfaces = {
    writer = {
      host              = local.writer_host
      port              = local.writer_port
      username          = local.mysql_username
      password          = sensitive(local.mysql_password)
      database          = local.mysql_database
      connection_string = local.writer_connection_string != null ? sensitive(local.writer_connection_string) : null
      secrets           = ["password", "connection_string"]
    }
    reader = local.create_read_service ? {
      host              = local.reader_host
      port              = local.reader_port
      username          = local.mysql_username
      password          = sensitive(local.mysql_password)
      database          = local.mysql_database
      connection_string = local.reader_connection_string != null ? sensitive(local.reader_connection_string) : null
      secrets           = ["password", "connection_string"]
      } : {
      # Fallback to writer if no read replicas
      host              = local.writer_host
      port              = local.writer_port
      username          = local.mysql_username
      password          = sensitive(local.mysql_password)
      database          = local.mysql_database
      connection_string = local.writer_connection_string != null ? sensitive(local.writer_connection_string) : null
      secrets           = ["password", "connection_string"]
    }
  }
}