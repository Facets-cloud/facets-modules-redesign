# MongoDB Cluster Module - Local Variables
# KubeBlocks v1.0.1

locals {
  # Cluster configuration
  cluster_name = var.instance_name
  namespace    = try(var.instance.spec.namespace_override, "") != "" ? var.instance.spec.namespace_override : var.environment.namespace
  replicas     = var.instance.spec.mode == "standalone" ? 1 : lookup(var.instance.spec, "replicas", 3)

  # HA settings
  ha_enabled = var.instance.spec.mode == "replication"

  # Anti-affinity settings (soft anti-affinity - prefers different nodes)
  ha_config                = lookup(var.instance.spec, "high_availability", {})
  enable_pod_anti_affinity = lookup(local.ha_config, "enable_pod_anti_affinity", true)

  # PDB settings - maxUnavailable=1 ensures only 1 pod disrupted at a time
  enable_pdb = lookup(local.ha_config, "enable_pdb", false) && local.ha_enabled

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

  # Topology from ClusterDefinition
  # KubeBlocks MongoDB only supports "replicaset" topology (default)
  # Standalone vs HA is controlled by replicas count, not topology
  # Sharding topology exists but requires different components (mongos, config-server, shards)
  topology = "replicaset"

  # Backup settings - mapped to ClusterBackup API
  backup_config = lookup(var.instance.spec, "backup", {})

  # Ensure boolean types
  backup_enabled = try(lookup(local.backup_config, "enabled", false), false) == true

  # Backup schedule settings (for Cluster.spec.backup)
  backup_schedule_enabled = true
  backup_cron_expression  = try(lookup(local.backup_config, "schedule_cron", "0 2 * * *"), "0 2 * * *")
  backup_retention_period = try(lookup(local.backup_config, "retention_period", "7d"), "7d")

  # Backup method - volume-snapshot for MongoDB
  backup_method = "volume-snapshot"

  # Restore configuration - annotation-based restore from backup
  restore_config  = lookup(var.instance.spec, "restore", {})
  restore_enabled = lookup(local.restore_config, "enabled", false) == true

  # Restore source details
  restore_backup_name = lookup(local.restore_config, "backup_name", "")

  # Component definition and version
  mongodb_version = var.instance.spec.mongodb_version

  # Component definition - fixed for all MongoDB versions
  # KubeBlocks uses a single version-agnostic component definition (mongodb-1.0.1)
  # The ClusterDefinition uses prefix matching (compDef: mongodb-) which matches this
  component_def = "mongodb-1.0.1"

  # Service version - the actual MongoDB version to deploy
  # This is specified in the Cluster spec.componentSpecs[].serviceVersion field
  # Supported versions from ComponentVersion: 8.0.8, 7.0.18, 6.0.21, 5.0.29, 4.4.29
  service_version = local.mongodb_version

  # MongoDB connection details
  admin_username = "root"
  admin_database = "admin"

  # Credentials from secret (to be read after cluster creation)
  mongodb_password = try(data.kubernetes_secret.mongodb_credentials.data["password"], "")

  # Validate password exists and is not empty
  password_is_valid = local.mongodb_password != "" && length(local.mongodb_password) > 0

  # Primary endpoint (always exists)
  primary_host = "${local.cluster_name}-mongodb-mongodb.${local.namespace}.svc"
  primary_port = 27017

  # Replica set name (KubeBlocks convention)
  replica_set_name = "${local.cluster_name}-mongodb"

  # Generate replica hosts for connection string
  replica_hosts = [
    for i in range(local.replicas) :
    "${local.cluster_name}-mongodb-${i}.${local.cluster_name}-mongodb-headless.${local.namespace}.svc:27017"
  ]

  # Connection string (with replica set for HA)
  connection_string = local.password_is_valid ? (
    local.ha_enabled ?
    "mongodb://${local.admin_username}:${local.mongodb_password}@${join(",", local.replica_hosts)}/${local.admin_database}?replicaSet=${local.replica_set_name}" :
    "mongodb://${local.admin_username}:${local.mongodb_password}@${local.primary_host}:${local.primary_port}/${local.admin_database}"
  ) : null

  # External Access configuration
  external_access_config = lookup(var.instance.spec, "external_access", {})
  has_external_access    = length(local.external_access_config) > 0
}
