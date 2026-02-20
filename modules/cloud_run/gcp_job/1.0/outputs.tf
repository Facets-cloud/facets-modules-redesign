# =============================================================================
# OUTPUTS
# =============================================================================

locals {
  output_attributes = {
    job_name   = google_cloud_run_v2_job.this.name
    location   = google_cloud_run_v2_job.this.location
    project_id = local.project_id

    # Job execution URI (for Cloud Tasks or manual triggering)
    execution_uri = "https://${local.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${local.project_id}/jobs/${local.job_name}:run"
  }

  output_interfaces = {}
}
