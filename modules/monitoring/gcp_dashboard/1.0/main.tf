# =============================================================================
# LOCAL COMPUTATIONS
# =============================================================================

locals {
  project_id = var.inputs.gcp_provider.attributes.project_id

  # display_name is the single source of truth for the dashboard's name. Folding
  # it into the body means the Console name can never drift from the blueprint,
  # and callers only have to set it in one place.
  dashboard_body = jsonencode(merge(
    jsondecode(var.instance.spec.dashboard_json),
    { displayName = var.instance.spec.display_name }
  ))

  # google_monitoring_dashboard.id is "projects/<project>/dashboards/<id>"; the
  # Console deep link needs the bare trailing id.
  dashboard_short_id = element(
    split("/", google_monitoring_dashboard.this.id),
    length(split("/", google_monitoring_dashboard.this.id)) - 1
  )
}

# =============================================================================
# DASHBOARD
# =============================================================================

resource "google_monitoring_dashboard" "this" {
  project        = local.project_id
  dashboard_json = local.dashboard_body
}
