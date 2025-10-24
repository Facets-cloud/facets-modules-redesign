# Generate a unique name for the AKS cluster
module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 63
  resource_name   = var.instance_name
  resource_type   = "k8s"
  globally_unique = true
}

# Create the AKS cluster using the locally modified Azure module
module "k8scluster" {
  source = "./k8scluster/v4"

  # Required variables
  resource_group_name = var.inputs.network_details.attributes.resource_group_name
  location            = var.inputs.network_details.attributes.region

  # Basic cluster configuration
  cluster_name        = local.name
  prefix              = local.name
  node_resource_group = "MC_${local.name}"

  # Kubernetes version is managed automatically by Azure auto-upgrade
  kubernetes_version = null

  # SKU tier
  sku_tier = var.instance.spec.cluster.sku_tier

  # Network configuration - fixed service CIDR to avoid conflicts
  network_plugin = "azure"
  network_policy = "calico"
  vnet_subnet = {
    id = var.inputs.network_details.attributes.private_subnet_ids[0]
  }
  net_profile_service_cidr   = "172.16.0.0/20"
  net_profile_dns_service_ip = "172.16.0.10"

  # Public cluster configuration - always enabled
  private_cluster_enabled         = false
  api_server_authorized_ip_ranges = var.instance.spec.cluster.cluster_endpoint_public_access_cidrs

  # Node pool configuration
  agents_count              = var.instance.spec.node_pools.system_np.node_count
  agents_size               = var.instance.spec.node_pools.system_np.instance_type
  agents_max_pods           = var.instance.spec.node_pools.system_np.max_pods
  os_disk_size_gb           = var.instance.spec.node_pools.system_np.os_disk_size_gb
  agents_availability_zones = var.inputs.network_details.attributes.availability_zones
  agents_pool_name          = "system"

  # Auto-scaling configuration
  enable_auto_scaling = var.instance.spec.node_pools.system_np.enable_auto_scaling
  agents_min_count    = var.instance.spec.node_pools.system_np.enable_auto_scaling ? var.instance.spec.node_pools.system_np.node_count : null
  agents_max_count    = var.instance.spec.node_pools.system_np.enable_auto_scaling ? 10 : null

  # System node pool - mark it as system mode
  only_critical_addons_enabled = true

  # Auto-upgrade configuration - always enabled
  automatic_channel_upgrade = var.instance.spec.auto_upgrade_settings.automatic_channel_upgrade

  # Maintenance window configuration - supports all frequency types
  maintenance_window_auto_upgrade = var.instance.spec.auto_upgrade_settings.maintenance_window.is_enabled ? {
    frequency = var.instance.spec.auto_upgrade_settings.maintenance_window.frequency
    interval  = var.instance.spec.auto_upgrade_settings.maintenance_window.interval
    duration  = var.instance.spec.auto_upgrade_settings.maintenance_window.end_time - var.instance.spec.auto_upgrade_settings.maintenance_window.start_time
    # Day of week - used for Weekly and RelativeMonthly
    day_of_week = contains(["Weekly", "RelativeMonthly"], var.instance.spec.auto_upgrade_settings.maintenance_window.frequency) ? var.instance.spec.auto_upgrade_settings.maintenance_window.day_of_week : null
    # Day of month - used for AbsoluteMonthly  
    day_of_month = var.instance.spec.auto_upgrade_settings.maintenance_window.frequency == "AbsoluteMonthly" ? var.instance.spec.auto_upgrade_settings.maintenance_window.day_of_month : null
    # Week index - used for RelativeMonthly
    week_index = var.instance.spec.auto_upgrade_settings.maintenance_window.frequency == "RelativeMonthly" ? var.instance.spec.auto_upgrade_settings.maintenance_window.week_index : null
    start_time = format("%02d:00", var.instance.spec.auto_upgrade_settings.maintenance_window.start_time)
    utc_offset = "+00:00"
  } : null

  # Node surge configuration for upgrades
  agents_pool_max_surge = var.instance.spec.auto_upgrade_settings.max_surge

  # Enable Azure Policy
  azure_policy_enabled = true

  # Enable workload identity and OIDC issuer
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  # Disable log analytics workspace
  log_analytics_workspace_enabled = false

  # Disable role assignments for application gateway
  create_role_assignments_for_application_gateway = false

  # Node labels for system node pool - configurable from spec
  agents_labels = var.instance.spec.node_pools.system_np.labels != null ? var.instance.spec.node_pools.system_np.labels : {}

  # Tags
  tags = merge(
    var.environment.cloud_tags,
    var.instance.spec.tags != null ? var.instance.spec.tags : {}
  )

  # Azure AD and RBAC configuration
  rbac_aad                    = true
  rbac_aad_azure_rbac_enabled = true

  # Keep local accounts enabled for compatibility with client certificate auth
  local_account_disabled = false
}
