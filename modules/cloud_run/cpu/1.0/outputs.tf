locals {
  # Output attributes matching @facets/cloudrun schema
  output_attributes = {
    service_name  = google_cloud_run_v2_service.this.name
    location      = google_cloud_run_v2_service.this.location
    url           = try(google_cloud_run_v2_service.this.uri, "")
    max_instances = lookup(lookup(var.instance.spec, "scaling", {}), "max_instances", 10)
  }

  # Output interfaces matching @facets/cloudrun schema
  output_interfaces = {
    http = {
      url          = try(google_cloud_run_v2_service.this.uri, "")
      protocol     = "https"
      service_name = google_cloud_run_v2_service.this.name
      location     = google_cloud_run_v2_service.this.location
    }
  }
}
