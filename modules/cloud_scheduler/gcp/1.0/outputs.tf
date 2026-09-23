# ╔═══════════════════════════════════════════════════════════╗
# ║ Output contract: @facets/cloud_scheduler_job             ║
# ║ Keys managed by CLI — fill in the values only           ║
# ║ Do not add or remove keys. Do not rename.                 ║
# ║                                                           ║
# ║ View schema: raptor get output-type @facets/cloud_schedu ║
# ╚═══════════════════════════════════════════════════════════╝

locals {
  output_attributes = {
    id            = google_cloud_scheduler_job.this.id
    name          = google_cloud_scheduler_job.this.name
    project_id    = local.project_id
    region        = local.region
    resource_name = google_cloud_scheduler_job.this.id
    schedule      = google_cloud_scheduler_job.this.schedule
    state         = google_cloud_scheduler_job.this.state
  }
  output_interfaces = {
  }
}

# --- END MANAGED SECTION --- Add your custom outputs below ---

# Add your custom Terraform outputs below this line.
