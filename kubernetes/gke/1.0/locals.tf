locals {
  # Extract spec values with defaults
  spec = lookup(var.instance, "spec", {})

  # Basic cluster configuration
  initial_node_count = lookup(local.spec, "initial_node_count", 3)
  machine_type       = lookup(local.spec, "machine_type", "e2-standard-4")
  disk_size_gb       = 100           # Hardcoded to match legacy default
  disk_type          = "pd-standard" # Hardcoded to match legacy default

  # Auto-upgrade settings
  auto_upgrade    = lookup(local.spec, "auto_upgrade", true)
  release_channel = local.auto_upgrade ? "STABLE" : "UNSPECIFIED" # Hardcoded to STABLE

  # Autoscaling configuration
  enable_autoscaling = lookup(local.spec, "enable_autoscaling", true)
  min_nodes          = lookup(local.spec, "min_nodes", 1)
  max_nodes          = lookup(local.spec, "max_nodes", 10)

  # Network configuration from VPC module
  network_attributes = lookup(var.inputs.network_details, "attributes", {})
  project_id         = lookup(var.inputs.cloud_account, "attributes", {}).project_id
  region             = lookup(var.inputs.cloud_account, "attributes", {}).region

  # VPC integration
  vpc_network         = lookup(local.network_attributes, "vpc_id", "")
  subnet              = lookup(local.network_attributes, "private_subnet_id", "")
  pods_range_name     = lookup(local.network_attributes, "gke_pods_range_name", "")
  services_range_name = lookup(local.network_attributes, "gke_services_range_name", "")

  # Security settings
  whitelisted_cidrs = lookup(local.spec, "whitelisted_cidrs", ["0.0.0.0/0"])

  # Cluster naming (using name module)
  cluster_name = module.name.name

  # Labels - only from environment
  cluster_labels = var.environment.cloud_tags
}