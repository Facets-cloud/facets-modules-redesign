module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 63
  resource_name   = var.instance_name
  resource_type   = "service"
  globally_unique = false
}

# Cloud Run Service
resource "google_cloud_run_v2_service" "this" {
  name     = local.service_name
  location = local.location
  project  = local.project_id

  labels      = local.all_labels
  annotations = lookup(var.instance.spec, "annotations", {})

  # Ingress configuration
  ingress = local.ingress_value

  deletion_protection = false

  template {
    # Scaling configuration
    scaling {
      min_instance_count = lookup(var.instance.spec.runtime.autoscaling, "min", 0)
      max_instance_count = lookup(var.instance.spec.runtime.autoscaling, "max", 10)
    }

    # Request timeout
    timeout = "${lookup(var.instance.spec, "timeout", "300")}s"

    # Service account - always use the module-created service account
    service_account = google_service_account.this.email

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
          read_only = lookup(volumes.value, "read_only", false)
        }
      }
    }

    # Container configuration
    containers {
      image = var.instance.spec.release.image

      # Ports
      ports {
        container_port = tonumber(var.instance.spec.runtime.port)
      }

      # Command and args
      command = lookup(var.instance.spec.runtime, "command", null)
      args    = lookup(var.instance.spec.runtime, "args", null)

      # Environment variables - only non-empty values have secrets; skip empty ones
      dynamic "env" {
        for_each = lookup(var.instance.spec, "env", {})
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.env_vars[env.key].secret_id
              version = google_secret_manager_secret_version.env_vars[env.key].version
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

      # Resources
      resources {
        limits = {
          cpu    = lookup(var.instance.spec.runtime.size, "cpu", "1000m")
          memory = lookup(var.instance.spec.runtime.size, "memory", "512Mi")
        }
        cpu_idle          = local.cpu_idle
        startup_cpu_boost = lookup(var.instance.spec.runtime.size, "startup_cpu_boost", false)
      }

      # Startup probe
      dynamic "startup_probe" {
        for_each = local.startup_probe_enabled ? [1] : []
        content {
          http_get {
            path = lookup(var.instance.spec.runtime.health_checks.startup_probe, "path", "/health/startup")
            port = tonumber(var.instance.spec.runtime.port)
          }
          initial_delay_seconds = lookup(var.instance.spec.runtime.health_checks.startup_probe, "initial_delay", 0)
          timeout_seconds       = lookup(var.instance.spec.runtime.health_checks.startup_probe, "timeout", 1)
          period_seconds        = lookup(var.instance.spec.runtime.health_checks.startup_probe, "period", 10)
          failure_threshold     = lookup(var.instance.spec.runtime.health_checks.startup_probe, "failure_threshold", 3)
        }
      }

      # Liveness probe
      dynamic "liveness_probe" {
        for_each = local.liveness_probe_enabled ? [1] : []
        content {
          http_get {
            path = lookup(var.instance.spec.runtime.health_checks.liveness_probe, "path", "/health/live")
            port = tonumber(var.instance.spec.runtime.port)
          }
          initial_delay_seconds = lookup(var.instance.spec.runtime.health_checks.liveness_probe, "initial_delay", 0)
          timeout_seconds       = lookup(var.instance.spec.runtime.health_checks.liveness_probe, "timeout", 1)
          period_seconds        = lookup(var.instance.spec.runtime.health_checks.liveness_probe, "period", 10)
          failure_threshold     = lookup(var.instance.spec.runtime.health_checks.liveness_probe, "failure_threshold", 3)
        }
      }
    }

    # Max concurrent requests per instance
    max_instance_request_concurrency = lookup(var.instance.spec.runtime.autoscaling, "concurrency", 80)
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
