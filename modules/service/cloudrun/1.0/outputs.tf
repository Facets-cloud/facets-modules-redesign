locals {
  output_attributes = {
    service_name = google_cloud_run_v2_service.this.name
    location     = google_cloud_run_v2_service.this.location
    url          = try(google_cloud_run_v2_service.this.uri, "")
  }

  # Cloud Run services expose HTTP endpoints
  output_interfaces = {
    http = {
      url          = try(google_cloud_run_v2_service.this.uri, "")
      protocol     = "https"
      service_name = google_cloud_run_v2_service.this.name
      location     = google_cloud_run_v2_service.this.location
    }
  }
}
