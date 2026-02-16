# GCP Service Account — auto-created for AWS federation
# This SA gets bound to K8s service accounts via Workload Identity,
# then used to assume the AWS IAM Role via Google OIDC

# Create the GCP Service Account
# account_id is hard-capped at 30 chars (GCP limit)
resource "google_service_account" "this" {
  account_id   = local.gcp_sa_account_id
  display_name = "AWS Federation SA for ${local.name}"
  project      = local.gcp_project_id
  description  = "Auto-created by Facets for GKE-to-AWS cross-cloud federation"
}

# Bind each Kubernetes service account to this GCP SA via Workload Identity
# This allows GKE pods running as these K8s SAs to act as this GCP SA
resource "google_service_account_iam_member" "workload_identity" {
  for_each           = toset(local.service_accounts_list)
  service_account_id = google_service_account.this.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.gcp_project_id}.svc.id.goog[${local.namespace}/${each.value}]"
}
