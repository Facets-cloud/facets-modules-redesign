# =============================================================================
# NAME MODULE - Ensure Cloud Scheduler job name respects length limit
# =============================================================================

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 500
  resource_name = var.instance_name
  resource_type = "scheduler"
}

# =============================================================================
# LOCAL COMPUTATIONS
# =============================================================================

locals {
  project_id = var.inputs.gcp_provider.attributes.project_id
  region     = var.inputs.gcp_provider.attributes.region

  spec         = var.instance.spec
  target       = local.spec.target
  auth         = lookup(local.spec, "auth", null)
  retry_config = lookup(local.spec, "retry_config", null)

  # Auth: oauth_token and oidc_token are mutually exclusive (set only one at use time)
  oauth_email = local.auth != null ? lookup(local.auth, "oauth_service_account_email", null) : null
  oidc_email  = local.auth != null ? lookup(local.auth, "oidc_service_account_email", null) : null
}

# =============================================================================
# ENABLE REQUIRED APIS
# =============================================================================

resource "google_project_service" "scheduler" {
  project            = local.project_id
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

# =============================================================================
# CLOUD SCHEDULER JOB
# =============================================================================

resource "google_cloud_scheduler_job" "this" {
  name    = module.name.name
  project = local.project_id
  region  = local.region

  schedule         = local.spec.schedule
  time_zone        = lookup(local.spec, "time_zone", "Etc/UTC")
  attempt_deadline = lookup(local.spec, "attempt_deadline", "180s")
  description      = lookup(local.spec, "description", null)
  paused           = lookup(local.spec, "paused", false)

  http_target {
    uri         = local.target.uri
    http_method = lookup(local.target, "http_method", "POST")
    body        = lookup(local.target, "body", null) != null ? base64encode(local.target.body) : null
    headers     = lookup(local.target, "headers", {})

    dynamic "oauth_token" {
      for_each = local.oauth_email != null ? [1] : []
      content {
        service_account_email = local.oauth_email
        scope                 = lookup(local.auth, "oauth_scope", null)
      }
    }

    dynamic "oidc_token" {
      for_each = local.oidc_email != null ? [1] : []
      content {
        service_account_email = local.oidc_email
        audience              = lookup(local.auth, "oidc_audience", null)
      }
    }
  }

  dynamic "retry_config" {
    for_each = local.retry_config != null ? [local.retry_config] : []
    content {
      retry_count          = lookup(retry_config.value, "retry_count", null)
      max_retry_duration   = lookup(retry_config.value, "max_retry_duration", null)
      min_backoff_duration = lookup(retry_config.value, "min_backoff_duration", null)
      max_backoff_duration = lookup(retry_config.value, "max_backoff_duration", null)
      max_doublings        = lookup(retry_config.value, "max_doublings", null)
    }
  }

  depends_on = [google_project_service.scheduler]
}
