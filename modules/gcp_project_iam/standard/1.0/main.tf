terraform {
  required_version = ">= 1.0"
}

resource "google_project_iam_member" "this" {
  for_each = local.role_member_pairs_by_id

  project = var.inputs.project.attributes.project_id
  role    = each.value.role
  member  = each.value.member
}

resource "google_project_iam_audit_config" "this" {
  for_each = local.audit_configs_by_service

  project = var.inputs.project.attributes.project_id
  service = each.key

  dynamic "audit_log_config" {
    for_each = toset(each.value.audit_log_types)

    content {
      log_type         = audit_log_config.value
      exempted_members = toset(each.value.exempted_members)
    }
  }
}
