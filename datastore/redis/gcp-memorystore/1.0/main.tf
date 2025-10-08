# Use existing private services connection from network module when available
# Falls back to default VPC for testing when network module is not provided
# The network module provides private service networking in production

# Import existing Redis instance if specified
# Import blocks with dynamic IDs are not supported in Terraform
# The import functionality will be handled by the Facets platform
# using the import declaration in facets.yaml

# Generate random auth string for Redis (not needed for imports - Redis generates its own)
# Removed conditional resource creation to prevent issues during import operations
# The imported Redis instance will have its own auth_string that we reference directly

# Redis Memorystore Instance
# Uses existing private services connection provided by the network module when available
resource "google_redis_instance" "main" {
  name           = local.instance_name
  tier           = local.tier
  memory_size_gb = local.memory_size_gb

  # Location configuration
  region      = local.region
  location_id = local.location_id

  # Network configuration - use existing private services connection when available
  # For testing without network module, this will create in default network
  authorized_network = local.authorized_network
  connect_mode       = local.authorized_network != null ? "PRIVATE_SERVICE_ACCESS" : "DIRECT_PEERING"

  # Redis configuration
  redis_version = local.redis_version
  display_name  = "Redis instance for ${var.instance_name}"

  # Security configuration (hardcoded for security)
  # These settings are managed by ignore_changes for imported resources
  auth_enabled            = true
  transit_encryption_mode = local.authorized_network != null ? "SERVER_AUTHENTICATION" : "DISABLED"

  # High availability for standard tier
  # These settings are managed by ignore_changes for imported resources
  replica_count      = local.tier == "STANDARD_HA" ? 1 : 0
  read_replicas_mode = local.tier == "STANDARD_HA" ? "READ_REPLICAS_ENABLED" : "READ_REPLICAS_DISABLED"

  # Labels for resource management
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

  # Lifecycle management
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      # Core immutable attributes (cannot be changed after creation)
      name,               # Instance name cannot be changed
      region,             # Region cannot be changed after creation
      location_id,        # Location cannot be changed after creation
      authorized_network, # Network configuration should not change
      connect_mode,       # Connection mode should not change

      # Configuration attributes that may drift or be managed externally
      labels,                  # Ignore label changes (managed by tags)
      display_name,            # Ignore display name changes
      transit_encryption_mode, # Ignore encryption mode changes (immutable after creation)
      auth_enabled,            # Ignore auth changes (should remain enabled)
      replica_count,           # Ignore replica count changes (managed by tier)
      read_replicas_mode,      # Ignore read replica mode changes (managed by tier)

      # Version can be upgraded through GCP console/CLI, ignore drift
      redis_version, # Allow manual version upgrades through GCP

      # For imported resources, ignore these computed values
      tier,           # Service tier (imported resources keep existing)
      memory_size_gb, # Memory size (imported resources keep existing)
    ]
  }

  # Restore from backup is handled by GCP's point-in-time recovery features
  # This is typically done through Google Cloud Console or gcloud CLI
  # rather than Terraform configuration
}

# Note: This module is designed to work with or without a network module
# 
# With network module (production):
# - Uses private service access and existing VPC from network module
# - Provides proper network isolation and security
# - Requires network module to provide private services connection
#
# Without network module (testing):
# - Falls back to default VPC with direct peering
# - Suitable for testing but not recommended for production
# - May have limited security and networking capabilities