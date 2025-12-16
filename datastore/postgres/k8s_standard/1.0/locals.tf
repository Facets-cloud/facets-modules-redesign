# PostgreSQL Cluster Module - Local Variables
# KubeBlocks v1.0.1

locals {
  # Cluster configuration
  cluster_name = var.instance_name # Use instance_name as cluster name
  namespace    = try(var.instance.spec.namespace_override, "") != "" ? var.instance.spec.namespace_override : var.environment.namespace
  replicas     = var.instance.spec.mode == "standalone" ? 1 : lookup(var.instance.spec, "replicas", 2)

  # HA settings
  ha_enabled               = var.instance.spec.mode == "replication"
  enable_pod_anti_affinity = true # Always enable pod anti-affinity for HA deployments
  create_read_service      = true # Always create read service for replication mode

  # Get node pool details from input
  node_pool_input  = lookup(var.inputs, "node_pool", {})
  node_pool_attrs  = lookup(local.node_pool_input, "attributes", {})
  node_selector    = lookup(local.node_pool_attrs, "node_selector", {})
  node_pool_taints = lookup(local.node_pool_attrs, "taints", [])

  # Convert taints from {key, value, effect} to tolerations format
  tolerations = [
    for taint in local.node_pool_taints : {
      key      = taint.key
      operator = "Equal"
      value    = taint.value
      effect   = taint.effect
    }
  ]

  topology = local.ha_enabled ? "replication" : "standalone"

  # Backup settings - mapped to ClusterBackup API
  backup_config = lookup(var.instance.spec, "backup", {})

  # Ensure boolean types
  backup_enabled = try(lookup(local.backup_config, "enabled", false), false) == true

  # Backup schedule settings (for Cluster.spec.backup)
  backup_schedule_enabled = true
  backup_cron_expression  = try(lookup(local.backup_config, "schedule_cron", "0 2 * * *"), "0 2 * * *")
  backup_retention_period = try(lookup(local.backup_config, "retention_period", "7d"), "7d")

  # Backup method - (For volume-snapshot, no repo needed)
  backup_method = "volume-snapshot"

  # Restore configuration - annotation-based restore from backup
  restore_config  = lookup(var.instance.spec, "restore", {})
  restore_enabled = lookup(local.restore_config, "enabled", false) == true

  # Restore source details
  # Backup naming pattern from KubeBlocks:
  # - Volume-snapshot backups: {cluster-name}-backup-{timestamp}
  restore_backup_name = lookup(local.restore_config, "backup_name", "")

  # Component definition
  postgres_version = var.instance.spec.postgres_version

  # Extract major version only (first segment)
  # For PostgreSQL: 12.15.0 -> 12, 14.8.0 -> 14, 16.4.0 -> 16
  postgres_major = split(".", local.postgres_version)[0]

  # Build the componentDef such as postgresql-12-1.0.1, postgresql-14-1.0.1, postgresql-16-1.0.1
  # The release version is fixed at 1.0.1 for the current KubeBlocks addon
  release_version = "1.0.1"

  component_def = "postgresql-${local.postgres_major}-${local.release_version}"

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
}
