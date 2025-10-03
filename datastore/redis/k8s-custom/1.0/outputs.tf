locals {
  output_attributes = {
    helm_release_name         = helm_release.postgresql.name
    namespace                 = helm_release.postgresql.namespace
    primary_service_name      = local.primary_service_name
    read_replica_service_name = local.enable_replication ? local.replica_service_name : null
    secret_name               = local.secret_name
    database_name             = local.database_name
    master_username           = local.master_username
    port                      = local.postgres_port
    architecture              = local.architecture
    version                   = local.postgres_version
    storage_size              = local.storage_size
    storage_class             = local.storage_class
  }
  output_interfaces = {
    writer = {
      host              = "${local.primary_service_name}.${local.namespace}.svc.cluster.local"
      username          = local.master_username
      password          = local.master_password
      connection_string = "postgres://${local.master_username}:${local.master_password}@${local.primary_service_name}.${local.namespace}.svc.cluster.local:${local.postgres_port}/${local.database_name}"
    }
    reader = {
      host              = local.enable_replication ? "${local.replica_service_name}.${local.namespace}.svc.cluster.local" : "${local.primary_service_name}.${local.namespace}.svc.cluster.local"
      username          = local.master_username
      password          = local.master_password
      connection_string = local.enable_replication ? "postgres://${local.master_username}:${local.master_password}@${local.replica_service_name}.${local.namespace}.svc.cluster.local:${local.postgres_port}/${local.database_name}" : "postgres://${local.master_username}:${local.master_password}@${local.primary_service_name}.${local.namespace}.svc.cluster.local:${local.postgres_port}/${local.database_name}"
    }
  }
}