# Dedicated service account attached to every VM instance in the MIG
resource "google_service_account" "this" {
  account_id   = local.sa_name
  display_name = "VM service account for ${local.vm_name}"
  project      = local.project_id
}

# User-defined IAM roles from spec.cloud_permissions.gcp.roles
resource "google_project_iam_member" "cloud_permissions" {
  for_each = {
    for key, val in try(var.instance.spec.cloud_permissions.gcp.roles, {}) : key => val
  }

  project = local.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.this.email}"

  dynamic "condition" {
    for_each = try(each.value.condition, null) != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      expression  = condition.value.expression
      description = try(condition.value.description, null)
    }
  }
}
