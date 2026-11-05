locals {
  output_attributes = {
    loki_url        = "http://${local.loki_endpoint}"
    namespace       = local.namespace
    service_account = google_service_account.loki_gcs.email
    bucket_name     = local.bucket_name
  }

  output_interfaces = {
    default = {
      url = "http://${local.loki_endpoint}"
    }
  }
}
