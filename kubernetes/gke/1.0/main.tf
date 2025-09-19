# Generate a unique name for the GKE cluster
module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 63
  resource_name   = var.instance_name
  resource_type   = "k8s"
  globally_unique = true
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = local.name
  location = local.location

  # Network configuration
  network    = local.network
  subnetwork = local.subnetwork

  # Logging service configuration
  logging_service = local.enable_logging ? "logging.googleapis.com/kubernetes" : "none"

  # Monitoring service configuration
  monitoring_service = local.enable_logging ? "monitoring.googleapis.com/kubernetes" : "none"

  # Logging configuration
  logging_config {
    enable_components = local.enabled_log_components
  }

  # Monitoring configuration
  monitoring_config {
    enable_components = local.enabled_log_components
  }

  # Release channel for automatic upgrades
  release_channel {
    channel = local.release_channel
  }

  # Private cluster configuration
  dynamic "private_cluster_config" {
    for_each = local.enable_private_cluster ? [1] : []
    content {
      enable_private_nodes    = true
      enable_private_endpoint = false
      master_ipv4_cidr_block  = local.master_ipv4_cidr_block

      master_global_access_config {
        enabled = true
      }
    }
  }

  # IP allocation policy
  ip_allocation_policy {
    cluster_secondary_range_name  = lookup(local.network_attributes, "pods_range_name", "")
    services_secondary_range_name = lookup(local.network_attributes, "services_range_name", "")
  }

  # Master authorized networks
  master_auth {
    client_certificate_config {
      issue_client_certificate = true
    }
  }

  dynamic "master_authorized_networks_config" {
    for_each = length(local.authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = local.authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  # Network policy
  dynamic "network_policy" {
    for_each = local.enable_network_policy ? [1] : []
    content {
      enabled  = true
      provider = "CALICO"
    }
  }

  # Workload Identity
  dynamic "workload_identity_config" {
    for_each = local.enable_workload_identity ? [1] : []
    content {
      workload_pool = local.workload_identity_namespace
    }
  }

  # Addons configuration
  addons_config {
    http_load_balancing {
      disabled = false
    }

    horizontal_pod_autoscaling {
      disabled = false
    }

    dynamic "network_policy_config" {
      for_each = local.enable_network_policy ? [1] : []
      content {
        disabled = false
      }
    }
  }

  # Maintenance policy
  dynamic "maintenance_policy" {
    for_each = local.maintenance_window_enabled ? [1] : []
    content {
      recurring_window {
        start_time = "${formatdate("YYYY-MM-DD", timestamp())}T${local.maintenance_window_start}:00Z"
        end_time   = "${formatdate("YYYY-MM-DD", timestamp())}T${local.maintenance_window_end}:00Z"
        recurrence = local.maintenance_window_recurrence
      }
    }
  }

  # Remove the default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # Resource labels
  resource_labels = local.cluster_labels

  # Prevent destroy
  lifecycle {
    prevent_destroy = true
  }
}

# System Node Pool
resource "google_container_node_pool" "system" {
  count = local.system_node_pool_enabled ? 1 : 0

  name     = "system-node-pool"
  location = local.location
  cluster  = google_container_cluster.primary.name

  # Initial node count
  initial_node_count = local.system_node_pool_autoscaling ? null : local.system_node_pool_count

  # Autoscaling configuration
  dynamic "autoscaling" {
    for_each = local.system_node_pool_autoscaling ? [1] : []
    content {
      min_node_count = local.system_node_pool_min_nodes
      max_node_count = local.system_node_pool_max_nodes
    }
  }

  # Node configuration
  node_config {
    preemptible  = false
    machine_type = local.system_node_pool_machine_type

    # Disk configuration
    disk_size_gb = local.system_node_pool_disk_size
    disk_type    = local.system_node_pool_disk_type

    # Service account
    service_account = google_service_account.node_pool.email

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append"
    ]

    # Node labels
    labels = local.node_labels

    # Node tags
    tags = ["gke-node", local.name]

    # Workload Identity
    dynamic "workload_metadata_config" {
      for_each = local.enable_workload_identity ? [1] : []
      content {
        mode = "GKE_METADATA"
      }
    }

    # Shielded instance config
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  # Management
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  # Prevent destroy
  lifecycle {
    prevent_destroy = true
  }
}

# Service account for node pool
resource "google_service_account" "node_pool" {
  account_id   = "${local.name}-node-pool-sa"
  display_name = "Service Account for ${local.name} Node Pool"
}

# IAM binding for the node pool service account
resource "google_project_iam_member" "node_pool_sa_permissions" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer"
  ])

  project = local.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.node_pool.email}"
}