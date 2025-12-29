resource "google_redis_instance" "main" {
  name           = local.instance_name
  tier           = local.tier
  memory_size_gb = local.memory_size_gb

  # Location configuration
  region      = local.region
  location_id = local.location_id

  # Network configuration - uses private service access from network module
  authorized_network = local.authorized_network
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  # Redis engine configuration
  redis_version = local.redis_version
  display_name  = "Redis instance for ${var.instance_name}"

  # Security configuration
  auth_enabled            = true
  transit_encryption_mode = local.enable_tls ? "SERVER_AUTHENTICATION" : "DISABLED"

  # High availability configuration (STANDARD_HA tier only)
  replica_count      = local.tier == "STANDARD_HA" ? 1 : 0
  read_replicas_mode = local.tier == "STANDARD_HA" ? "READ_REPLICAS_ENABLED" : "READ_REPLICAS_DISABLED"

  # Resource labels
  labels = merge(
    var.environment.cloud_tags,
    {
      managed-by    = "facets"
      instance-name = var.instance_name
      environment   = var.environment.name
      intent        = "redis"
      flavor        = "gcp-memorystore"
    }
  )

  # Lifecycle management - prevents accidental deletion and ignores external changes
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      region,
      location_id,
      authorized_network,
      connect_mode,
      labels,
      display_name,
      transit_encryption_mode,
      auth_enabled,
      replica_count,
      read_replicas_mode,
      redis_version,
      tier,
      memory_size_gb,
    ]
  }
}