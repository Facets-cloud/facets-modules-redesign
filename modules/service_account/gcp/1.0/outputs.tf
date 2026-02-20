locals {
  output_attributes = {
    service_account_id    = google_service_account.this.account_id
    service_account_email = google_service_account.this.email
    service_account_name  = google_service_account.this.name
    unique_id             = google_service_account.this.unique_id
    project_id            = var.inputs.cloud_account.attributes.project_id

    # Include service account key if created
    private_key = var.instance.spec.create_key ? google_service_account_key.this[0].private_key : ""

    # Mark sensitive fields
    secrets = var.instance.spec.create_key ? ["private_key"] : []
  }

  output_interfaces = {}
}
