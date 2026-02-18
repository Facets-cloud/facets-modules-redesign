# =============================================================================
# LOCAL COMPUTATIONS
# =============================================================================

locals {
  project_id = var.inputs.cloud_account.attributes.project_id

  # Queue region: use spec.region if provided, else cloudrun location
  queue_region = lookup(var.instance.spec, "region", var.inputs.cloudrun.attributes.location)

  # Cloud Run location (for IAM binding - may differ from queue region)
  cloudrun_location = var.inputs.cloudrun.attributes.location

  queue_name = "${var.instance_name}-${var.environment.unique_name}"

  # Target URL for Cloud Run service
  target_url  = var.inputs.cloudrun.attributes.url
  target_path = lookup(var.instance.spec, "target_path", "/process")

  # Extract host from URL (remove https://)
  target_host = replace(local.target_url, "https://", "")

  # Max concurrent dispatches from Cloud Run max_instances
  max_concurrent_dispatches = lookup(var.inputs.cloudrun.attributes, "max_instances", 10)

  # API endpoint for clients to create tasks (uses queue_region)
  api_endpoint = "https://cloudtasks.googleapis.com/v2/projects/${local.project_id}/locations/${local.queue_region}/queues/${local.queue_name}/tasks"

  # Retry config with defaults
  retry_config = lookup(var.instance.spec, "retry_config", {})
}

# =============================================================================
# ENABLE CLOUD TASKS API
# =============================================================================

resource "google_project_service" "cloudtasks" {
  project            = local.project_id
  service            = "cloudtasks.googleapis.com"
  disable_on_destroy = false
}

# =============================================================================
# SERVICE ACCOUNT FOR INVOKING CLOUD RUN
# =============================================================================

resource "google_service_account" "invoker" {
  project      = local.project_id
  account_id   = substr("${var.instance_name}-inv", 0, 28)
  display_name = "Cloud Tasks Invoker for ${var.instance_name}"
  description  = "Service account used by Cloud Tasks to invoke Cloud Run service"

  depends_on = [google_project_service.cloudtasks]
}

# =============================================================================
# IAM: ALLOW INVOKER SA TO CALL CLOUD RUN
# =============================================================================

resource "google_cloud_run_v2_service_iam_member" "invoker" {
  project  = local.project_id
  location = local.cloudrun_location # Cloud Run's actual location
  name     = var.inputs.cloudrun.attributes.service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.invoker.email}"
}

# =============================================================================
# CLOUD TASKS QUEUE WITH HTTP TARGET
# =============================================================================

resource "google_cloud_tasks_queue" "this" {
  name     = local.queue_name
  location = local.queue_region # Queue region (may differ from Cloud Run)
  project  = local.project_id

  # Rate limiting based on Cloud Run max_instances
  rate_limits {
    max_concurrent_dispatches = local.max_concurrent_dispatches
  }

  # Retry configuration
  retry_config {
    max_attempts       = lookup(local.retry_config, "max_attempts", 3)
    min_backoff        = lookup(local.retry_config, "min_backoff", "10s")
    max_backoff        = lookup(local.retry_config, "max_backoff", "3600s")
    max_doublings      = lookup(local.retry_config, "max_doublings", 4)
    max_retry_duration = "0s"
  }

  # Queue-level HTTP target - clients only need to send payload
  http_target {
    # Override URI for all tasks in queue
    uri_override {
      host = local.target_host

      path_override {
        path = local.target_path
      }

      scheme = "HTTPS"
    }

    # OIDC authentication - automatic token for Cloud Run
    oidc_token {
      service_account_email = google_service_account.invoker.email
      audience              = local.target_url
    }

    # Default headers
    header_overrides {
      header {
        key   = "Content-Type"
        value = "application/json"
      }
    }
  }

  depends_on = [
    google_project_service.cloudtasks,
    google_service_account.invoker
  ]
}
