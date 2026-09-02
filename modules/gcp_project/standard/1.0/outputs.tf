locals {
  output_interfaces = {}
  output_attributes = {
    project_id     = google_project.this.project_id
    project_number = tostring(google_project.this.number)
    project_name   = "projects/${google_project.this.project_id}"
    folder_id      = google_project.this.folder_id
    enabled_apis   = keys(google_project_service.apis)
  }
}
