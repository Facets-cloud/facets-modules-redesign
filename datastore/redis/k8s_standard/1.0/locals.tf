# Redis Cluster Module - Local Variables
# KubeBlocks v1.0.1

locals {
  # Cluster configuration
  cluster_name = var.instance_name # Using instance_name as cluster name
  namespace    = try(var.instance.spec.namespace_override, "") != "" ? var.instance.spec.namespace_override : var.environment.namespace

  # Mode-specific replica configuration
  mode = var.instance.spec.mode

  # For standalone: 1 replica (1 pod)
  # For replication: user-defined replicas (default 2)
  # For redis-cluster: user-defined replicas per shard (default 2 for HA)
  base_replicas = local.mode == "standalone" ? 1 : lookup(var.instance.spec, "replicas", 2)
  shards        = local.mode == "redis-cluster" ? lookup(var.instance.spec, "shards", 3) : 1

  # For redis-cluster: pods per shard (2 = 1 master + 1 replica for HA)
  # For other modes: use base_replicas
  replicas = local.mode == "redis-cluster" ? lookup(var.instance.spec, "replicas", 2) : local.base_replicas

  # HA settings
  ha_enabled               = local.mode == "replication" || local.mode == "redis-cluster"
  enable_pod_anti_affinity = local.ha_enabled ? true : false # Enable pod anti-affinity for HA modes
  create_read_service      = local.mode == "replication" # Only for replication mode with sentinel

  # Topology mapping based on mode
  # NOTE: redis-cluster mode uses `shardings` and does NOT set `spec.topology`
  topology = local.mode == "replication" ? "replication" : "standalone"


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

  # Build componentDef based on mode:
  # - redis-cluster mode: redis-cluster-7-1.0.1
  # - standalone/replication: redis-7-1.0.1
  component_def = local.mode == "redis-cluster" ? "redis-cluster-${local.redis_major}-${local.release_version}" : "redis-${local.redis_major}-${local.release_version}"

  # Sentinel configuration (for replication mode)
  # Sentinel typically uses its own major version (e.g., redis-sentinel-8-1.0.1)
  # For simplicity, we use the same major version as Redis for compatibility
  sentinel_component_def = "redis-sentinel-${local.redis_major}-${local.release_version}"
  sentinel_version       = local.redis_version
  sentinel_replicas      = 3 # Minimum 3 for quorum-based failover


  # Credentials from data field
  # Credentials from discovered account secret - works for all modes
  redis_username = local.mode == "redis-cluster" ? try(data.kubernetes_secret.redis_cluster_credentials[0].data["username"], "default") : try(data.kubernetes_secret.redis_credentials[0].data["username"], "default")

  redis_password = local.mode == "redis-cluster" ? try(data.kubernetes_secret.redis_cluster_credentials[0].data["password"], "") : try(data.kubernetes_secret.redis_credentials[0].data["password"], "")

  # Validate password exists and is not empty
  password_is_valid = local.redis_password != "" && length(local.redis_password) > 0

  # Redis default database (always 0 for Redis)
  redis_database = "0"

  # Writer/Primary endpoint (always exists)
  writer_host = "${local.cluster_name}-redis-redis.${local.namespace}.svc.cluster.local"
  writer_port = 6379

  redis_port = 6379

  # Reader endpoint (only for replication mode with Sentinel)
  reader_host = local.create_read_service ? "${local.cluster_name}-redis-redis-read.${local.namespace}.svc.cluster.local" : null
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
