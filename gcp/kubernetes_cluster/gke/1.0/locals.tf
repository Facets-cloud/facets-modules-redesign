locals {
  # Extract spec values with defaults
  spec = lookup(var.instance, "spec", {})

  # Auto-upgrade settings
  auto_upgrade    = lookup(local.spec, "auto_upgrade", true)
  release_channel = local.auto_upgrade ? "STABLE" : "UNSPECIFIED" # Hardcoded to STABLE

  # Network configuration from VPC module
  network_attributes = lookup(var.inputs.network_details, "attributes", {})
  project_id         = lookup(var.inputs.cloud_account, "attributes", {}).project_id
  region             = lookup(var.inputs.cloud_account, "attributes", {}).region
  credentials        = lookup(var.inputs.cloud_account, "attributes", {}).credentials

  # Network integration (using GCP terminology)
  network             = lookup(local.network_attributes, "vpc_id", "")
  subnetwork          = lookup(local.network_attributes, "private_subnet_id", "")
  pods_range_name     = lookup(local.network_attributes, "gke_pods_range_name", "")
  services_range_name = lookup(local.network_attributes, "gke_services_range_name", "")

  # Zones from network module (will be empty list if not provided, meaning all zones in region)
  node_locations = lookup(local.network_attributes, "zones", [])

  # Security settings
  whitelisted_cidrs = lookup(local.spec, "whitelisted_cidrs", ["0.0.0.0/0"])

  # Cluster naming (using name module)
  # GKE requires cluster names to start with a letter
  cluster_name = "gke-${module.name.name}"

  # Labels - only from environment
  cluster_labels = var.environment.cloud_tags
}
