locals {
  output_interfaces = {}
  output_attributes = {
    service_account_email = google_service_account.this.email
    service_account_name  = google_service_account.this.name
    service_account_id    = google_service_account.this.account_id
    unique_id             = google_service_account.this.unique_id
    project_id            = var.inputs.project.attributes.project_id
  }
}
