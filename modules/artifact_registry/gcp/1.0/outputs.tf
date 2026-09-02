locals {
  output_interfaces = {}
  output_attributes = {
    repository_id = google_artifact_registry_repository.this.repository_id
    location      = google_artifact_registry_repository.this.location
    registry_url  = local.repository_url
  }
}
