locals {
  # Credentials from data field
  postgres_username = try(data.kubernetes_secret.postgres_credentials.data["username"], "postgres")

  postgres_password = try(data.kubernetes_secret.postgres_credentials.data["password"], "")

  # Validate password exists and is not empty
  password_is_valid = local.postgres_password != "" && length(local.postgres_password) > 0

  postgres_database = "postgres"

  # Writer/Primary endpoint (always exists)
  writer_host = "${local.cluster_name}-postgresql.${local.namespace}.svc.cluster.local"
  writer_port = 5432

  # PgBouncer connection pool endpoints
  pgbouncer_host = local.writer_host
  pgbouncer_port = 6432

  # Reader endpoint (only for replication mode with read service)
  reader_host = local.create_read_service ? "${local.cluster_name}-postgresql-read.${local.namespace}.svc.cluster.local" : null
  reader_port = local.create_read_service ? 5432 : null

  # Writer connection string
  writer_connection_string = local.password_is_valid ? (
    "postgresql://${local.postgres_username}:${local.postgres_password}@${local.writer_host}:${local.writer_port}/${local.postgres_database}"
  ) : null

  # Reader connection string
  reader_connection_string = (local.reader_host != null && local.password_is_valid) ? (
    "postgresql://${local.postgres_username}:${local.postgres_password}@${local.reader_host}:${local.reader_port}/${local.postgres_database}"
  ) : null

  # Output attributes
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
      postgres = {
        "app.kubernetes.io/instance"   = local.cluster_name
        "app.kubernetes.io/managed-by" = "kubeblocks"
        "app.kubernetes.io/name"       = "postgresql"
      }
    }
    defaultDatabase = local.postgres_database
  }

  # Output interfaces (credentials and connection details)
  output_interfaces = {
    # Writer interface (primary/master)
    writer = {
      host              = local.writer_host
      port              = local.writer_port
      username          = local.postgres_username
      password          = sensitive(local.postgres_password)
      database          = local.postgres_database
      connection_string = local.writer_connection_string != null ? sensitive(local.writer_connection_string) : null
      pgbouncer_host    = local.pgbouncer_host
      pgbouncer_port    = local.pgbouncer_port
      secrets           = ["password", "connection_string"]
    }
    # Reader interface (read replicas)
    # If no read service exists, point to writer
    reader = local.create_read_service ? {
      host              = local.reader_host
      port              = local.reader_port
      username          = local.postgres_username
      password          = sensitive(local.postgres_password)
      database          = local.postgres_database
      connection_string = local.reader_connection_string != null ? sensitive(local.reader_connection_string) : null
      secrets           = ["password", "connection_string"]
      } : {
      # Fallback to writer if no read replicas
      host              = local.writer_host
      port              = local.writer_port
      username          = local.postgres_username
      password          = sensitive(local.postgres_password)
      database          = local.postgres_database
      connection_string = local.writer_connection_string != null ? sensitive(local.writer_connection_string) : null
      secrets           = ["password", "connection_string"]
    }
  }
}