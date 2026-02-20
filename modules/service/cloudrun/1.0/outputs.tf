locals {
  # Output attributes matching @facets/service schema
  output_attributes = {
    service_name        = google_cloud_run_v2_service.this.name
    namespace           = local.location
    resource_name       = var.instance_name
    resource_type       = "cloudrun"
    selector_labels     = jsonencode(local.all_labels)
    service_account_arn = lookup(var.instance.spec, "service_account", "")
  }

  # Output interfaces - Cloud Run exposes HTTP endpoint
  output_interfaces = {
    http = {
      host      = google_cloud_run_v2_service.this.uri
      port      = tonumber(var.instance.spec.container.port)
      port_name = "http"
      name      = google_cloud_run_v2_service.this.name
      username  = ""
      password  = ""
      secrets   = []
    }
  }
}
