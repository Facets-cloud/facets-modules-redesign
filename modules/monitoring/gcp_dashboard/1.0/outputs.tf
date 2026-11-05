# =============================================================================
# OUTPUTS - Facets uses local.output_attributes and local.output_interfaces
# =============================================================================

locals {
  output_attributes = {
    project_id   = local.project_id
    dashboard_id = google_monitoring_dashboard.this.id
    display_name = var.instance.spec.display_name
    console_url  = "https://console.cloud.google.com/monitoring/dashboards/builder/${local.dashboard_short_id}?project=${local.project_id}"
  }

  output_interfaces = {}
}
