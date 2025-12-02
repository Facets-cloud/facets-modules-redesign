# Redis Cluster Module - Local Variables
# KubeBlocks v1.0.1

locals {
  # Cluster configuration
  cluster_name = "myapp-redis" # Default cluster name
  namespace    = try(var.instance.spec.namespace_override, "") != "" ? var.instance.spec.namespace_override : var.environment.namespace

  # Mode-specific replica configuration
  mode = var.instance.spec.mode

  # For standalone: 1 replica
  # For replication: user-defined replicas (default 2)
  # For redis-cluster: shards * replicas (each shard has replicas)
  base_replicas = local.mode == "standalone" ? 1 : lookup(var.instance.spec, "replicas", 2)
  shards        = local.mode == "redis-cluster" ? lookup(var.instance.spec, "shards", 3) : 1

  # Total replicas for redis-cluster mode
  replicas = local.mode == "redis-cluster" ? local.shards : local.base_replicas

  # HA settings
  ha_enabled               = local.mode == "replication" || local.mode == "redis-cluster"
  enable_pod_anti_affinity = local.ha_enabled && lookup(lookup(var.instance.spec, "high_availability", {}), "enable_pod_anti_affinity", true)
  create_read_service      = local.mode == "replication" # Only for replication mode with sentinel

  # Topology mapping based on mode
  topology = local.mode == "redis-cluster" ? "redis-cluster" : (local.mode == "replication" ? "replication" : "standalone")

  # Backup settings - mapped to ClusterBackup API
  backup_config = lookup(var.instance.spec, "backup", {})

  # Ensure boolean types
  backup_enabled = try(lookup(local.backup_config, "enabled", false), false) == true

  # Backup schedule settings (for Cluster.spec.backup)
  backup_schedule_enabled = local.backup_enabled && try(lookup(local.backup_config, "enable_schedule", false), false) == true
  backup_cron_expression  = try(lookup(local.backup_config, "schedule_cron", "0 2 * * *"), "0 2 * * *")
  backup_retention_period = try(lookup(local.backup_config, "retention_period", "7d"), "7d")

  # Backup method - volume-snapshot for Redis
  backup_method = "volume-snapshot"

  # Restore configuration - annotation-based restore from backup
  restore_config  = lookup(var.instance.spec, "restore", {})
  restore_enabled = lookup(local.restore_config, "enabled", false) == true

  # Restore source details
  # Backup naming pattern from KubeBlocks:
  # - Volume-snapshot backups: {cluster-name}-backup-{timestamp}
  restore_backup_name = lookup(local.restore_config, "backup_name", "")

  # Component definition
  redis_version = var.instance.spec.redis_version

  # Extract major version
  redis_major = split(".", local.redis_version)[0]

  # Fixed release version for addon
  release_version = "1.0.1"

  # Build componentDef: redis-7-1.0.1, redis-8-1.0.1 ...
  component_def = "redis-${local.redis_major}-${local.release_version}"


  # Credentials from data field
  redis_username = try(data.kubernetes_secret.redis_credentials.data["username"], "default")
  redis_password = try(data.kubernetes_secret.redis_credentials.data["password"], "")

  # Validate password exists and is not empty
  password_is_valid = local.redis_password != "" && length(local.redis_password) > 0

  # Redis default database (always 0 for Redis)
  redis_database = "0"

  # Writer/Primary endpoint (always exists)
  writer_host = "${local.cluster_name}-redis.${local.namespace}.svc.cluster.local"
  writer_port = 6379

  # Reader endpoint (only for replication mode with Sentinel)
  reader_host = local.create_read_service ? "${local.cluster_name}-redis-read.${local.namespace}.svc.cluster.local" : null
  reader_port = local.create_read_service ? 6379 : null

  # Writer connection string (Redis URI format)
  writer_connection_string = local.password_is_valid ? (
    "redis://:${local.redis_password}@${local.writer_host}:${local.writer_port}/${local.redis_database}"
  ) : null

  # Reader connection string
  reader_connection_string = (local.reader_host != null && local.password_is_valid) ? (
    "redis://:${local.redis_password}@${local.reader_host}:${local.reader_port}/${local.redis_database}"
  ) : null
}
