locals {
  output_attributes = {
    # Map of logical name -> GCP secret_id (short name within project).
    secret_ids = { for k, v in google_secret_manager_secret.this : k => v.secret_id }

    # Map of logical name -> full GCP resource name (projects/{project}/secrets/{id}).
    secret_names = { for k, v in google_secret_manager_secret.this : k => v.name }

    # GCP project that owns all the secrets.
    project_id = var.inputs.cloud_account.attributes.project_id
  }

  # Secret Manager secrets have no network endpoints.
  output_interfaces = {}
}
