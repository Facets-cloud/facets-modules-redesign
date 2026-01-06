locals {
  # Spec configuration
  spec = lookup(var.instance, "spec", {})

  # Tags
  metadata          = lookup(var.instance, "metadata", {})
  user_defined_tags = lookup(local.metadata, "tags", {})
  tags              = merge(local.user_defined_tags, var.environment.cloud_tags)

  # Network configuration from @facets/azure-network-details
  resource_group_name = var.inputs.network_details.attributes.resource_group_name
  region              = var.inputs.network_details.attributes.region

  # Use database subnet if available, otherwise fall back to private subnet
  subnet_id = coalesce(
    var.inputs.network_details.attributes.database_general_subnet_id,
    var.inputs.network_details.attributes.private_subnet_ids[0]
  )

  # VNet ID for Private DNS Zone linking
  vnet_id = var.inputs.network_details.attributes.vnet_id

  # Resource naming - inline approach (same as azure_cache_custom)
  cache_name = "${var.instance_name}-${var.environment.unique_name}"

  # Size to SKU mapping - Developer-friendly names to Azure Managed Redis SKUs
  # Balanced SKUs provide good mix of compute and memory
  size_to_sku = {
    small  = "Balanced_B1"   # ~1GB, suitable for dev/test
    medium = "Balanced_B5"   # ~6GB, small production
    large  = "Balanced_B50"  # ~30GB, high-traffic
    xlarge = "Balanced_B100" # ~60GB, enterprise
  }

  size     = lookup(local.spec, "size", "small")
  sku_name = lookup(local.size_to_sku, local.size, "Balanced_B1")

  # Advanced settings
  advanced = lookup(local.spec, "advanced", {})

  # Clustering mode mapping
  clustering_mode_to_policy = {
    standard          = "OSSCluster"
    legacy_compatible = "EnterpriseCluster"
  }

  clustering_mode   = lookup(local.advanced, "clustering_mode", "standard")
  clustering_policy = lookup(local.clustering_mode_to_policy, local.clustering_mode, "OSSCluster")

  # Authentication
  enable_password_auth               = lookup(local.advanced, "enable_password_auth", true)
  access_keys_authentication_enabled = local.enable_password_auth

  # Protocol configuration
  client_protocol = "Encrypted" # Always use TLS

  # Eviction policy
  eviction_policy = "VolatileLRU" # Standard Redis eviction for volatile keys

  # Azure Managed Redis port (different from legacy Redis Cache)
  redis_port = 10000

  # Username for connection strings
  username = "default"
}
