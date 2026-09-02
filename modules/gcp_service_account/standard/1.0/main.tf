terraform {
  required_version = ">= 1.0"
}

resource "google_service_account" "this" {
  account_id   = var.instance.spec.account_id
  display_name = lookup(var.instance.spec, "display_name", "Facets Terraform")
  description  = lookup(var.instance.spec, "description", "Managed by Facets")
  project      = var.inputs.project.attributes.project_id
}

resource "google_project_iam_member" "project_roles" {
  for_each = local.project_roles_by_id

  project = var.inputs.project.attributes.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.this.email}"
}

resource "google_service_account_iam_member" "token_creators" {
  for_each = local.token_creators_by_id

  service_account_id = google_service_account.this.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.value
}
