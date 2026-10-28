# GCP branch — GKE cluster. count-gated on the linked account being GCP.
resource "google_container_cluster" "this" {
  count = local.is_gcp ? 1 : 0

  name     = local.gke_cluster_name
  location = local.gcp_location # zone (zonal) when gcp.zone set, else account region (regional)

  min_master_version  = local.cluster_version
  deletion_protection = false

  # Manage node pools via the nodepool module; remove the default pool but keep a valid create count.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Attach to the linked network resource.
  network    = local.network_id
  subnetwork = local.gcp_subnetwork

  release_channel {
    channel = local.gcp_release_channel
  }

  private_cluster_config {
    enable_private_nodes    = local.gcp_enable_private_nodes
    enable_private_endpoint = false
  }

  # Workload Identity (GCP SA <-> KSA federation) — on by default.
  dynamic "workload_identity_config" {
    for_each = local.gcp_workload_identity && local.gcp_project != null ? [1] : []
    content {
      workload_pool = "${local.gcp_project}.svc.id.goog"
    }
  }

  # GKE cost management / resource usage insights.
  dynamic "cost_management_config" {
    for_each = local.gcp_cost_management ? [1] : []
    content {
      enabled = true
    }
  }

  # VPC-native (alias IP) networking — bind pods/services to the network's secondary ranges.
  dynamic "ip_allocation_policy" {
    for_each = local.gcp_use_vpc_native ? [1] : []
    content {
      cluster_secondary_range_name  = local.gcp_pods_range
      services_secondary_range_name = local.gcp_services_range
    }
  }

  # Network policy (Calico) — pod-level firewalling.
  dynamic "network_policy" {
    for_each = local.gcp_network_policy ? [1] : []
    content {
      enabled  = true
      provider = "CALICO"
    }
  }

  # Control-plane + workload logging.
  dynamic "logging_config" {
    for_each = local.gcp_logging_enabled ? [1] : []
    content {
      enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
    }
  }

  # Google Managed Prometheus toggle.
  dynamic "monitoring_config" {
    for_each = [1]
    content {
      managed_prometheus {
        enabled = local.gcp_managed_prometheus
      }
    }
  }

  # Restrict control-plane access to the given CIDRs (empty = no restriction).
  dynamic "master_authorized_networks_config" {
    for_each = length(local.gcp_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = local.gcp_authorized_networks
        content {
          display_name = cidr_blocks.key
          cidr_block   = cidr_blocks.value
        }
      }
    }
  }

  # Node Auto Provisioning (NAP) — cluster auto-creates/sizes node pools within these limits.
  dynamic "cluster_autoscaling" {
    for_each = local.gcp_nap_enabled ? [1] : []
    content {
      enabled = true
      resource_limits {
        resource_type = "cpu"
        minimum       = local.gcp_nap_min_cpu
        maximum       = local.gcp_nap_max_cpu
      }
      resource_limits {
        resource_type = "memory"
        minimum       = local.gcp_nap_min_memory
        maximum       = local.gcp_nap_max_memory
      }
      auto_provisioning_defaults {
        oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
      }
    }
  }

  # Recurring maintenance window (both start time + recurrence required).
  dynamic "maintenance_policy" {
    for_each = local.gcp_maint_start != "" && local.gcp_maint_recurrence != "" ? [1] : []
    content {
      recurring_window {
        start_time = local.gcp_maint_start
        end_time   = local.gcp_maint_start
        recurrence = local.gcp_maint_recurrence
      }
    }
  }
}

# ── Default system node pool (gated by spec.default_node_pool.enabled on a GCP account) ──
# A small node pool created WITH the GKE cluster for system workloads. count-gated to 0 when off, so
# the cluster is control-plane-only by default (the module already removes GKE's default pool).
resource "google_container_node_pool" "system" {
  count = local.gcp_default_pool ? 1 : 0

  name     = "${local.gke_cluster_name}-sys"
  project  = local.gcp_project
  location = local.dp_gcp_location # must match the cluster's location
  cluster  = google_container_cluster.this[0].name

  # Zone pinning (optional): restrict nodes to a subset of the cluster's zones. Empty = cluster default.
  node_locations = length(local.dp_gcp_node_locations) > 0 ? local.dp_gcp_node_locations : null

  # Fixed size when autoscaling is off; autoscaling block otherwise.
  node_count = local.dp_gcp_autoscaling ? null : local.dp_gcp_min_nodes

  dynamic "autoscaling" {
    for_each = local.dp_gcp_autoscaling ? [1] : []
    content {
      min_node_count = local.dp_gcp_min_nodes
      max_node_count = local.dp_gcp_max_nodes
    }
  }

  management {
    auto_repair  = local.dp_gcp_auto_repair
    auto_upgrade = local.dp_gcp_auto_upgrade
  }

  upgrade_settings {
    max_surge       = local.dp_gcp_max_surge
    max_unavailable = local.dp_gcp_max_unavail
  }

  max_pods_per_node = local.dp_gcp_max_pods

  node_config {
    machine_type    = local.dp_gcp_machine_type
    disk_type       = local.dp_gcp_disk_type
    disk_size_gb    = local.dp_gcp_disk_size
    spot            = local.dp_gcp_spot
    image_type      = local.dp_gcp_image_type
    service_account = local.dp_gcp_sa_email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels = {
      "workload-type" = "system"
      "node-role"     = "system"
    }

    shielded_instance_config {
      enable_secure_boot          = local.dp_gcp_secure_boot
      enable_integrity_monitoring = local.dp_gcp_integrity
    }

    # Serve the GKE metadata server to pods (hides node metadata and enables Workload Identity).
    # Requires the cluster's workload_identity_config, so it follows the same toggle.
    dynamic "workload_metadata_config" {
      for_each = local.gcp_workload_identity && local.gcp_project != null ? [1] : []
      content {
        mode = "GKE_METADATA"
      }
    }
  }

  lifecycle {
    ignore_changes = [node_config[0].labels]
  }
}
