module "sa-name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 30
  globally_unique = false
  resource_name   = var.instance_name
  resource_type   = ""
  is_k8s          = false
  prefix          = "sa"
}

resource "google_service_account" "sa" {
  count = length(local.iam_roles) > 0 ? 1 : 0

  account_id   = module.sa-name.name
  display_name = "Terraform-managed service account that Node Pool can use"
}

resource "google_project_iam_member" "np-account-iam" {
  for_each = local.iam_roles

  project = google_service_account.sa[0].project
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.sa[0].email}"
}

resource "random_string" "name_suffix" {
  length  = 4
  special = false
  lower   = true
  upper   = false
}

resource "google_container_node_pool" "node_pool" {
  project  = var.inputs.cloud_account.attributes.project_id
  provider = google-beta
  name     = "${var.instance_name}-${random_string.name_suffix.result}"
  cluster  = lookup(local.kubernetes_attributes, "cluster_id", "")
  location = var.inputs.cloud_account.attributes.region

  autoscaling {
    total_min_node_count = local.autoscaling_per_zone ? null : lookup(local.spec, "min_node_count", null)
    total_max_node_count = local.autoscaling_per_zone ? null : lookup(local.spec, "max_node_count", null)
    min_node_count       = local.autoscaling_per_zone ? lookup(local.spec, "min_node_count", null) : null
    max_node_count       = local.autoscaling_per_zone ? lookup(local.spec, "max_node_count", null) : null
  }

  management {
    auto_repair  = local.auto_repair
    auto_upgrade = local.auto_upgrade
  }

  initial_node_count = lookup(local.spec, "min_node_count", null)
  max_pods_per_node  = local.max_pods_per_node
  node_locations     = local.node_locations

  upgrade_settings {
    max_surge       = lookup(local.spec, "max_surge", 1)
    max_unavailable = lookup(local.spec, "max_unavailable", 0)
  }
  version = lookup(local.kubernetes_attributes, "cluster_version", "")

  node_config {
    machine_type = lookup(local.spec, "instance_type", null)
    image_type   = "COS_CONTAINERD"
    disk_size_gb = lookup(local.spec, "disk_size", null)
    dynamic "taint" {
      for_each = local.taints
      content {
        key    = taint.value["key"]
        value  = taint.value["value"]
        effect = taint.value["effect"]
      }
    }
    labels          = local.labels
    resource_labels = merge(var.environment.cloud_tags, lookup(lookup(var.instance, "metadata", {}), "labels", {}))
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = length(local.iam_roles) > 0 ? google_service_account.sa[0].email : null
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    disk_type = lookup(local.spec, "disk_type", "pd-standard")
    metadata = {
      disable-legacy-endpoints = "true"
    }
    preemptible = lookup(local.spec, "preemptible", false)
    tags = [
      "gke-${lookup(local.kubernetes_attributes, "cluster_name", "")}"
    ]
    spot = local.spot

    dynamic "sandbox_config" {
      for_each = tobool(lookup(local.spec, "sandbox_enabled", false)) ? ["gvisor"] : []
      content {
        sandbox_type = sandbox_config.value
      }
    }

    dynamic "guest_accelerator" {
      for_each = lookup(local.spec, "guest_accelerator", {})
      content {
        type  = guest_accelerator.value["type"]
        count = guest_accelerator.value["count"]
      }
    }

    shielded_instance_config {
      enable_secure_boot          = lookup(lookup(local.spec, "shielded_instance_config", {}), "enable_secure_boot", false)
      enable_integrity_monitoring = lookup(lookup(local.spec, "shielded_instance_config", {}), "enable_integrity_monitoring", true)
    }

    kubelet_config {
      cpu_manager_policy = lookup(local.spec, "cpu_manager_policy", "static")
      cpu_cfs_quota      = lookup(local.spec, "cpu_cfs_quota", false)
      pod_pids_limit     = lookup(local.spec, "pod_pids_limit", 0)
    }
  }

  network_config {
    ## ID of the secondary range for pod IPs in string
    pod_range            = local.pod_ip_range_name
    enable_private_nodes = !lookup(local.spec, "is_public", false)
  }

  lifecycle {
    ignore_changes        = [version, node_config.0.image_type, initial_node_count, network_config.0.enable_private_nodes]
    create_before_destroy = true
    prevent_destroy       = true
  }
}
