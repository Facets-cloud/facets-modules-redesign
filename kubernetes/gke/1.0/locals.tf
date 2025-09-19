locals {
  # Generate cluster name using name module
  name = module.name.name

  # Base spec sections as local variables
  spec                  = lookup(var.instance, "spec", {})
  cluster_spec          = lookup(local.spec, "cluster", {})
  auto_upgrade_spec     = lookup(local.spec, "auto_upgrade_settings", {})
  system_node_pool_spec = lookup(local.spec, "system_node_pool", {})
  security_spec         = lookup(local.spec, "security", {})
  logging_spec          = lookup(local.spec, "logging", {})

  # Sub-objects within auto_upgrade_spec
  maintenance_window_spec = lookup(local.auto_upgrade_spec, "maintenance_window", {})

  # Network details attributes as local
  network_attributes = lookup(var.inputs.network_details, "attributes", {})

  # Basic configuration
  project_id = lookup(local.network_attributes, "project_id", "")

  # Network configuration
  network    = lookup(local.network_attributes, "network_self_link", "")
  subnetwork = lookup(local.network_attributes, "subnet_self_link", "")
  region     = lookup(local.network_attributes, "region", "")

  # Cluster location (always regional, simplified from location_type)
  location = local.region

  # Cluster settings
  cluster_endpoint_public_access_cidrs = lookup(local.cluster_spec, "cluster_endpoint_public_access_cidrs", ["0.0.0.0/0"])

  # Auto-upgrade settings
  release_channel = lookup(local.auto_upgrade_spec, "release_channel", "REGULAR")

  # Maintenance window settings
  maintenance_window_enabled    = lookup(local.maintenance_window_spec, "is_enabled", true)
  maintenance_window_start      = lookup(local.maintenance_window_spec, "start_time", "02:00")
  maintenance_window_end        = lookup(local.maintenance_window_spec, "end_time", "06:00")
  maintenance_window_recurrence = lookup(local.maintenance_window_spec, "recurrence", "FREQ=WEEKLY;BYDAY=SU")

  # System node pool settings
  system_node_pool_enabled      = lookup(local.system_node_pool_spec, "enabled", true)
  system_node_pool_count        = lookup(local.system_node_pool_spec, "node_count", 3)
  system_node_pool_machine_type = lookup(local.system_node_pool_spec, "machine_type", "e2-medium")
  system_node_pool_disk_size    = lookup(local.system_node_pool_spec, "disk_size_gb", 100)
  system_node_pool_disk_type    = lookup(local.system_node_pool_spec, "disk_type", "pd-standard")
  system_node_pool_autoscaling  = lookup(local.system_node_pool_spec, "enable_autoscaling", true)
  system_node_pool_min_nodes    = lookup(local.system_node_pool_spec, "min_nodes", 1)
  system_node_pool_max_nodes    = lookup(local.system_node_pool_spec, "max_nodes", 10)
  system_node_pool_labels_spec = lookup(local.system_node_pool_spec, "labels", {
    "facets.cloud/node-type" = "system"
    "managed-by"             = "facets"
  })

  # Security settings
  enable_private_cluster   = lookup(local.security_spec, "enable_private_cluster", true)
  enable_network_policy    = lookup(local.security_spec, "enable_network_policy", true)
  enable_workload_identity = lookup(local.security_spec, "enable_workload_identity", true)
  master_ipv4_cidr_block   = lookup(local.security_spec, "master_ipv4_cidr_block", "10.0.0.0/28")

  # Labels/Tags
  spec_tags = lookup(local.spec, "tags", {})
  cluster_labels = merge(
    local.spec_tags,
    var.environment.cloud_tags,
    {
      managed-by   = "facets"
      cluster-name = local.name
      environment  = var.environment.name
    }
  )

  # Node pool labels
  node_labels = merge(
    local.system_node_pool_labels_spec,
    {
      environment = var.environment.name
    }
  )

  # Authorized networks
  authorized_networks = [
    for cidr in local.cluster_endpoint_public_access_cidrs : {
      cidr_block   = cidr
      display_name = "Allowed CIDR: ${cidr}"
    }
  ]

  # Workload identity namespace
  workload_identity_namespace = local.enable_workload_identity ? "${local.project_id}.svc.id.goog" : null

  # Logging configuration
  enable_logging                   = lookup(local.logging_spec, "enable_logging", false)
  log_retention_days               = lookup(local.logging_spec, "log_retention_days", 30)
  enable_workloads_logging         = lookup(local.logging_spec, "enable_workloads_logging", true)
  enable_api_server_logging        = lookup(local.logging_spec, "enable_api_server_logging", true)
  enable_system_components_logging = lookup(local.logging_spec, "enable_system_components_logging", false)

  # Construct enabled log components list based on individual toggles
  enabled_log_components = local.enable_logging ? compact([
    local.enable_workloads_logging ? "WORKLOADS" : "",
    local.enable_api_server_logging ? "APISERVER" : "",
    local.enable_system_components_logging ? "SYSTEM_COMPONENTS" : ""
  ]) : []
}