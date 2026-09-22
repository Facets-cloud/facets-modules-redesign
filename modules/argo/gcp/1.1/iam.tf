# ── Workflows Workload Identity ─────────────────────────────────────────────

resource "google_service_account" "workflows" {
  count        = local.workflows_enabled ? 1 : 0
  account_id   = local.workflows_sa_id
  display_name = "Argo Workflows SA for ${var.environment.name}"
  project      = local.project_id
}

resource "google_project_iam_member" "workflows_roles" {
  for_each = local.workflows_enabled ? local.workflows_sa_roles : {}
  project  = local.project_id
  role     = each.value.role
  member   = "serviceAccount:${google_service_account.workflows[0].email}"
}

resource "google_service_account_iam_member" "workflows_wi" {
  count              = local.workflows_enabled ? 1 : 0
  service_account_id = google_service_account.workflows[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.project_id}.svc.id.goog[${local.workflows_sa_namespace}/${local.workflows_sa_name}]"
}
