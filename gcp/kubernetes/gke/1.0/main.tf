module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 32
  resource_name   = var.instance_name
  resource_type   = "kubernetes_cluster"
  globally_unique = true
}

# Data source to get access token for Kubernetes provider
data "google_client_config" "default" {}

# GKE Cluster with default node pool
resource "google_container_cluster" "primary" {
  name     = local.cluster_name
  location = local.region # Regional cluster for HA

  # Allow cluster deletion
  deletion_protection = false

  # Remove default node pool - manage all node pools via kubernetes_node_pool module
  remove_default_node_pool = true
  initial_node_count       = 1 # Required for creation, then immediately removed

  # Network configuration
  network    = local.network
  subnetwork = local.subnetwork

  # IP allocation policy for pods and services
  ip_allocation_policy {
    cluster_secondary_range_name  = local.pods_range_name
    services_secondary_range_name = local.services_range_name
  }

  # Release channel for automatic upgrades
  dynamic "release_channel" {
    for_each = local.auto_upgrade ? [1] : []
    content {
      channel = local.release_channel
    }
  }

  # Private nodes with public endpoint
  private_cluster_config {
    enable_private_nodes    = true  # Nodes have private IPs only (secure)
    enable_private_endpoint = false # API accessible from internet (manageable)
    # master_ipv4_cidr_block  = "10.0.0.0/28" # Required for private nodes

    master_global_access_config {
      enabled = true
    }
  }

  # Whitelisted CIDRs for API access
  dynamic "master_authorized_networks_config" {
    for_each = length(local.whitelisted_cidrs) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = local.whitelisted_cidrs
        content {
          cidr_block   = cidr_blocks.value
          display_name = "Whitelisted: ${cidr_blocks.value}"
        }
      }
    }
  }

  # Enable network policy (Calico)
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Enable workload identity for secure access to GCP services
  workload_identity_config {
    workload_pool = "${local.project_id}.svc.id.goog"
  }

  # Addons configuration
  addons_config {
    http_load_balancing {
      disabled = false
    }

    horizontal_pod_autoscaling {
      disabled = false
    }

    network_policy_config {
      disabled = false
    }

    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  # Binary authorization for image security
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Logging configuration
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  # Monitoring configuration
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  # Maintenance policy - only when auto-upgrade is enabled
  # Daily maintenance window at 3 AM UTC for 4 hours
  dynamic "maintenance_policy" {
    for_each = local.auto_upgrade ? [1] : []
    content {
      daily_maintenance_window {
        start_time = "03:00"
      }
    }
  }

  # Resource labels
  resource_labels = local.cluster_labels
}
