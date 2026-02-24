# One Secret Manager secret per environment variable key
resource "google_secret_manager_secret" "env_vars" {
  for_each  = lookup(var.instance.spec, "env", {})
  secret_id = "${local.service_name}-env-${lower(replace(each.key, "_", "-"))}"
  project   = local.project_id

  replication {
    auto {}
  }

  labels = local.all_labels
}

resource "google_secret_manager_secret_version" "env_vars" {
  for_each    = lookup(var.instance.spec, "env", {})
  secret      = google_secret_manager_secret.env_vars[each.key].id
  secret_data = (each.value == null || each.value == "") ? "NOT_SPECIFIED" : each.value
}