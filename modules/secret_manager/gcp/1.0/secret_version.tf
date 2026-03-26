resource "google_secret_manager_secret_version" "initial" {
  # Iterate over keys only — sensitive values cannot be used as for_each arguments.
  # The actual sensitive value is accessed inside the resource body via local.all_entries[each.key].
  for_each = toset(keys(local.all_entries))

  secret = google_secret_manager_secret.this[each.key].id
  # Use a placeholder if the resolved value is empty (e.g. secret not yet set in Facets).
  # lifecycle.ignore_changes means this placeholder will never overwrite a real value on re-runs.
  secret_data = local.all_entries[each.key] != "" ? local.all_entries[each.key] : "PLACEHOLDER_NOT_SET"

  # Prevent Terraform from overwriting the value on subsequent deploys.
  # All version updates must be performed manually via GCP Console or gcloud.
  lifecycle {
    ignore_changes = [secret_data]
  }
}
