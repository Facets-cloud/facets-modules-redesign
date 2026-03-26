# =============================================================================
# OUTPUTS (Facets reads from these locals automatically)
# =============================================================================

locals {
  output_attributes = {
    # Job identifiers
    job_name = google_cloud_run_v2_job.this.name
    job_id   = google_cloud_run_v2_job.this.id
    job_uid  = google_cloud_run_v2_job.this.uid

    # Location
    location   = local.region
    project_id = local.project_id

    # Execution API endpoint
    execution_url = "https://run.googleapis.com/v2/projects/${local.project_id}/locations/${local.region}/jobs/${google_cloud_run_v2_job.this.name}:run"

    # Job config
    task_count  = local.task_count
    parallelism = local.parallelism
    max_retries = local.max_retries

    # GPU info
    gpu_enabled = local.gpu_enabled
    gpu_type    = local.gpu_type
  }

  output_interfaces = {
    jobs_api = {
      endpoint     = "https://run.googleapis.com/v2/projects/${local.project_id}/locations/${local.region}/jobs/${google_cloud_run_v2_job.this.name}:run"
      http_method  = "POST"
      content_type = "application/json"
      description  = "Trigger job execution via Cloud Run Admin API"
    }
  }
}
