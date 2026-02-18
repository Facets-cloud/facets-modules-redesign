# =============================================================================
# OUTPUTS (Facets reads from these locals automatically)
# =============================================================================

locals {
  output_attributes = {
    # Queue identifiers
    queue_name = google_cloud_tasks_queue.this.name
    queue_path = "projects/${local.project_id}/locations/${local.queue_region}/queues/${google_cloud_tasks_queue.this.name}"

    # Location info
    queue_region      = local.queue_region
    cloudrun_location = local.cloudrun_location
    project_id        = local.project_id

    # API endpoint for clients to create tasks
    api_endpoint = local.api_endpoint

    # Target Cloud Run URL and path (pre-configured in queue)
    target_url  = local.target_url
    target_path = local.target_path

    # Invoker service account (used by queue for OIDC)
    invoker_sa_email = google_service_account.invoker.email

    # Queue configuration mode
    http_target_mode = "queue_level"
  }

  output_interfaces = {
    tasks_api = {
      endpoint     = local.api_endpoint
      http_method  = "POST"
      content_type = "application/json"
      description  = "Create tasks with just body payload - URL and auth handled by queue"
    }
  }
}
