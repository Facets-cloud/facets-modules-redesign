locals {
  # Basic configuration
  namespace          = "redis-${var.instance_name}-${var.environment.unique_name}"
  redis_name         = var.instance_name
  redis_version      = var.instance.spec.version_config.redis_version
  architecture       = var.instance.spec.version_config.architecture
  enable_replication = var.instance.spec.version_config.architecture == "replication"

  # Resource sizing
  memory_limit  = var.instance.spec.sizing.memory_limit
  cpu_limit     = var.instance.spec.sizing.cpu_limit
  storage_size  = var.instance.spec.sizing.storage_size
  replica_count = var.instance.spec.version_config.architecture == "replication" ? var.instance.spec.sizing.replica_count : 0

  # Service names - simplified for standalone mode
  master_service_name  = "${local.redis_name}-redis-master"
  replica_service_name = "${local.redis_name}-redis-replica"
  secret_name          = "${local.redis_name}-redis-secret"

  # Redis configuration
  redis_port     = 6379
  redis_password = random_password.redis_auth.result

  # Restore configuration
  restore_from_backup = var.instance.spec.restore_config != null ? lookup(var.instance.spec.restore_config, "restore_from_backup", false) : false
  backup_source_path  = var.instance.spec.restore_config != null ? lookup(var.instance.spec.restore_config, "backup_source_path", "") : ""

  # Import configuration
  import_helm_release = var.instance.spec.imports != null ? lookup(var.instance.spec.imports, "helm_release_name", null) : null
  import_secret_name  = var.instance.spec.imports != null ? lookup(var.instance.spec.imports, "secret_name", null) : null
  import_service_name = var.instance.spec.imports != null ? lookup(var.instance.spec.imports, "service_name", null) : null
}