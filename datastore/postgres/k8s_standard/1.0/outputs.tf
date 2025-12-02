locals {
  output_attributes = {
    cluster_name      = local.cluster_name
    namespace         = local.namespace
    postgres_version  = var.instance.spec.postgres_version
    mode              = var.instance.spec.mode
    replicas          = local.replicas
    resource_type     = "postgres"
    resource_name     = var.instance_name
    primary_service   = try(data.kubernetes_service.postgres_primary.metadata[0].name, "${local.cluster_name}-postgresql")
    read_service      = local.reader_host != null ? try(kubernetes_service.postgres_read[0].metadata[0].name, null) : null
    connection_secret = try(data.kubernetes_secret.postgres_credentials.metadata[0].name, "${local.cluster_name}-conn-credential")
    pod_prefix = {
      writer = "${local.cluster_name}-postgresql"
      reader = local.create_read_service ? "${local.cluster_name}-postgresql-read" : null
    }
    selectors = {
      postgresql = {
        "app.kubernetes.io/instance"   = local.cluster_name
        "app.kubernetes.io/managed-by" = "kubeblocks"
        "app.kubernetes.io/name"       = "postgresql"
      }
    }
    defaultDatabase = local.postgres_database
  }
  output_interfaces = {
    writer = {
      host              = local.writer_host
      port              = local.writer_port
      username          = local.postgres_username
      password          = local.postgres_password
      database          = local.postgres_database
      connection_string = local.writer_connection_string
      pgbouncer_host    = local.pgbouncer_host
      pgbouncer_port    = local.pgbouncer_port
      secrets           = ["password", "connection_string"]
    }
    reader = local.create_read_service ? {
      host              = local.reader_host
      port              = local.reader_port
      username          = local.postgres_username
      password          = local.postgres_password
      database          = local.postgres_database
      connection_string = local.reader_connection_string
      secrets           = ["password", "connection_string"]
      } : {
      host              = local.writer_host
      port              = local.writer_port
      username          = local.postgres_username
      password          = local.postgres_password
      database          = local.postgres_database
      connection_string = local.writer_connection_string
      secrets           = ["password", "connection_string"]
    }
  }
}