terraform {
  required_version = ">= 1.0"
}

resource "google_project" "this" {
  project_id      = var.instance.spec.project_id
  name            = var.instance.spec.display_name
  folder_id       = var.inputs.parent_folder.attributes.folder_id
  billing_account = var.inputs.cloud_account.attributes.billing_account

  auto_create_network = false
  deletion_policy     = local.deletion_policy
  labels              = local.project_labels
}

resource "google_project_service" "apis" {
  for_each = toset(lookup(var.instance.spec, "activate_apis", []))

  project = google_project.this.project_id
  service = each.value

  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "time_sleep" "api_propagation" {
  depends_on      = [google_project_service.apis]
  create_duration = "60s"
}

resource "google_project_default_service_accounts" "deprivilege" {
  project        = google_project.this.project_id
  action         = local.default_sa_action
  restore_policy = "REVERT_AND_IGNORE_FAILURE"

  depends_on = [time_sleep.api_propagation]
}
