# Keys-only set for for_each - Terraform forbids sensitive maps as for_each arguments
# since values would be exposed as resource instance keys. Keys are safe to use.
locals {
  non_empty_env_keys = toset([
    for k, v in lookup(var.instance.spec, "env", {}) : k if v != null && v != ""
  ])
}

# One Secret Manager secret per environment variable key
resource "google_secret_manager_secret" "env_vars" {
  for_each  = local.non_empty_env_keys
  secret_id = "${local.service_name}-env-${lower(replace(each.key, "_", "-"))}"
  project   = local.project_id

  replication {
    auto {}
  }

  labels = local.all_labels
}

resource "google_secret_manager_secret_version" "env_vars" {
  for_each    = local.non_empty_env_keys
  secret      = google_secret_manager_secret.env_vars[each.key].id
  secret_data = var.instance.spec.env[each.key]
}
