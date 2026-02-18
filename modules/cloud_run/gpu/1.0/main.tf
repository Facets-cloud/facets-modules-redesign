locals {
  service_name = "${var.instance_name}-${var.environment.unique_name}"
  location     = var.inputs.gcp_provider.attributes.region
  project_id   = var.inputs.gcp_provider.attributes.project_id

  # Merge environment cloud tags with instance labels
  all_labels = merge(
    var.environment.cloud_tags,
    lookup(var.instance.spec, "labels", {})
  )

  # VPC connector configuration
  vpc_connector = (
    var.inputs.network != null &&
    lookup(var.instance.spec.vpc_access, "enabled", false)
  ) ? lookup(var.inputs.network.attributes, "vpc_connector_name", null) : null

  # Health check probes
  startup_probe_enabled  = lookup(var.instance.spec.health_checks.startup_probe, "enabled", true)
  startup_probe_type     = lookup(var.instance.spec.health_checks.startup_probe, "type", "tcp")
  liveness_probe_enabled = lookup(var.instance.spec.health_checks.liveness_probe, "enabled", false)
  liveness_probe_type    = lookup(var.instance.spec.health_checks.liveness_probe, "type", "http")

  # GPU configuration
  gpu_enabled = lookup(var.instance.spec.gpu, "enabled", false)
  gpu_type    = lookup(var.instance.spec.gpu, "type", "nvidia-l4")

  # Ingress configuration - map user-friendly values to GCP API values
  ingress_raw = lookup(var.instance.spec, "ingress", "")
  ingress_map = {
    ""                                  = ""
    "all"                               = "INGRESS_TRAFFIC_ALL"
    "internal"                          = "INGRESS_TRAFFIC_INTERNAL_ONLY"
    "internal-and-cloud-load-balancing" = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  }
  ingress_value = lookup(local.ingress_map, local.ingress_raw, "")
}

# Cloud Run Service with GPU support
resource "google_cloud_run_v2_service" "this" {
  name     = local.service_name
  location = local.location
  project  = local.project_id

  deletion_protection = false

  # RTX Pro 6000 GPU requires ALPHA launch stage
  launch_stage = local.gpu_type == "nvidia-rtx-pro-6000" ? "ALPHA" : null

  labels      = local.all_labels
  annotations = lookup(var.instance.spec, "annotations", {})

  ingress = local.ingress_value

  template {
    # GPU zonal redundancy configuration
    gpu_zonal_redundancy_disabled = !lookup(var.instance.spec.gpu, "zonal_redundancy", false)

    # Scaling configuration
    scaling {
      min_instance_count = var.instance.spec.scaling.min_instances
      max_instance_count = var.instance.spec.scaling.max_instances
    }

    # Request timeout
    timeout = "${lookup(var.instance.spec, "timeout", "600")}s"

    # Service account
    service_account = lookup(var.instance.spec, "service_account", null)

    # VPC Access
    dynamic "vpc_access" {
      for_each = local.vpc_connector != null ? [1] : []
      content {
        connector = local.vpc_connector
        egress    = upper(replace(lookup(var.instance.spec.vpc_access, "egress", "private-ranges-only"), "-", "_"))
      }
    }

    # GCS Fuse volumes
    dynamic "volumes" {
      for_each = lookup(var.instance.spec, "gcs_volumes", {})
      content {
        name = volumes.key
        gcs {
          bucket    = volumes.value.bucket
          read_only = lookup(volumes.value, "read_only", true)
        }
      }
    }

    # Container configuration
    containers {
      image = var.instance.spec.container.image

      # Ports
      ports {
        container_port = tonumber(var.instance.spec.container.port)
      }

      # Command and args
      command = lookup(var.instance.spec.container, "command", null)
      args    = lookup(var.instance.spec.container, "args", null)

      # Environment variables
      dynamic "env" {
        for_each = lookup(var.instance.spec, "env", {})
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secret environment variables
      dynamic "env" {
        for_each = lookup(var.instance.spec, "secrets", {})
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret_name
              version = lookup(env.value, "version", "latest")
            }
          }
        }
      }

      # GCS Fuse volume mounts
      dynamic "volume_mounts" {
        for_each = lookup(var.instance.spec, "gcs_volumes", {})
        content {
          name       = volume_mounts.key
          mount_path = volume_mounts.value.mount_path
        }
      }

      # Resources with GPU support
      resources {
        limits = merge(
          {
            cpu    = var.instance.spec.resources.cpu
            memory = var.instance.spec.resources.memory
          },
          local.gpu_enabled ? {
            "nvidia.com/gpu" = "1"
          } : {}
        )
        cpu_idle          = local.gpu_enabled ? false : (var.instance.spec.scaling.min_instances == 0)
        startup_cpu_boost = lookup(var.instance.spec.resources, "startup_cpu_boost", false)
      }

      # Startup probe - HTTP or TCP
      dynamic "startup_probe" {
        for_each = local.startup_probe_enabled ? [1] : []
        content {
          dynamic "http_get" {
            for_each = local.startup_probe_type == "http" ? [1] : []
            content {
              path = lookup(var.instance.spec.health_checks.startup_probe, "path", "/health/startup")
              port = tonumber(var.instance.spec.container.port)
            }
          }

          dynamic "tcp_socket" {
            for_each = local.startup_probe_type == "tcp" ? [1] : []
            content {
              port = tonumber(lookup(var.instance.spec.health_checks.startup_probe, "port", var.instance.spec.container.port))
            }
          }

          initial_delay_seconds = lookup(var.instance.spec.health_checks.startup_probe, "initial_delay", 0)
          timeout_seconds       = lookup(var.instance.spec.health_checks.startup_probe, "timeout", 30)
          period_seconds        = lookup(var.instance.spec.health_checks.startup_probe, "period", 60)
          failure_threshold     = lookup(var.instance.spec.health_checks.startup_probe, "failure_threshold", 10)
        }
      }

      # Liveness probe - HTTP or TCP
      dynamic "liveness_probe" {
        for_each = local.liveness_probe_enabled ? [1] : []
        content {
          dynamic "http_get" {
            for_each = local.liveness_probe_type == "http" ? [1] : []
            content {
              path = lookup(var.instance.spec.health_checks.liveness_probe, "path", "/health/live")
              port = tonumber(var.instance.spec.container.port)
            }
          }

          dynamic "tcp_socket" {
            for_each = local.liveness_probe_type == "tcp" ? [1] : []
            content {
              port = tonumber(lookup(var.instance.spec.health_checks.liveness_probe, "port", var.instance.spec.container.port))
            }
          }

          initial_delay_seconds = lookup(var.instance.spec.health_checks.liveness_probe, "initial_delay", 0)
          timeout_seconds       = lookup(var.instance.spec.health_checks.liveness_probe, "timeout", 1)
          period_seconds        = lookup(var.instance.spec.health_checks.liveness_probe, "period", 10)
          failure_threshold     = lookup(var.instance.spec.health_checks.liveness_probe, "failure_threshold", 3)
        }
      }
    }

    # GPU node selector
    dynamic "node_selector" {
      for_each = local.gpu_enabled ? [1] : []
      content {
        accelerator = local.gpu_type
      }
    }

    # Max concurrent requests per instance
    max_instance_request_concurrency = var.instance.spec.scaling.concurrency

    # User annotations only - system annotations not supported in API v2
    annotations = lookup(var.instance.spec, "annotations", {})
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to client and client_version as they're set by Terraform
      client,
      client_version,
    ]
  }
}

# IAM policy for unauthenticated access (allUsers)
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count = lookup(lookup(var.instance.spec, "auth", {}), "allow_unauthenticated", false) ? 1 : 0

  project  = local.project_id
  location = local.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
