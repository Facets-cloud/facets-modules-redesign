# ── GKE Workload Identity grants (same-cloud) ───────────────────────────────────────────────────
# Grant GCP IAM roles directly to this workload's Workload Identity principal (the KSA), so GKE pods
# reach GCP resources without a GSA or static keys. GCP-only: gated on the linked cloud_account
# being GCP and cloud_permissions.gcp.enable_wi (count-gated to 0 on AWS).
resource "google_project_iam_member" "wi" {
  for_each = local.wi_enabled ? local.wi_roles : {}
  project  = local.gcp_project
  role     = each.value.role
  member   = local.wi_member
}
