# =============================================================================
# OUTPUTS - Facets uses local.output_attributes and local.output_interfaces
# =============================================================================

locals {
  output_attributes = {
    project_id   = local.project_id
    policy_ids   = { for k, v in google_monitoring_alert_policy.this : k => v.id }
    policy_names = { for k, v in google_monitoring_alert_policy.this : k => v.name }
  }

  output_interfaces = {}
}
