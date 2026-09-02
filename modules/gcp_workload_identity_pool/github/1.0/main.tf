terraform {
  required_version = ">= 1.0"
}

resource "google_iam_workload_identity_pool" "this" {
  project                   = local.project_id
  workload_identity_pool_id = local.pool_id
  display_name              = "GitHub Actions"
  description               = "GitHub Actions Workload Identity Federation pool"
  disabled                  = false
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = local.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.this.workload_identity_pool_id
  workload_identity_pool_provider_id = local.provider_id
  display_name                       = "GitHub OIDC"
  description                        = "GitHub Actions OIDC provider"
  disabled                           = false

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = local.attribute_condition

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "repositories" {
  for_each = local.repository_bindings_by_id

  service_account_id = "projects/${local.project_id}/serviceAccounts/${var.instance.spec.service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = each.value.member
}
