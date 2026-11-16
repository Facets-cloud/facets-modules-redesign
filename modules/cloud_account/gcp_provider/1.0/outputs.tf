locals {
  output_interfaces = {}
  output_attributes = {
    project_id                  = data.external.gcp_fetch_cloud_secret.result["project"]
    project                     = data.external.gcp_fetch_cloud_secret.result["project"] # Keep for backward compatibility
    credentials                 = sensitive(data.external.gcp_fetch_cloud_secret.result["credentials"] == "" ? null : data.external.gcp_fetch_cloud_secret.result["credentials"])
    impersonate_service_account = data.external.gcp_fetch_cloud_secret.result["impersonate_service_account"] == "" ? null : data.external.gcp_fetch_cloud_secret.result["impersonate_service_account"]
    region                      = var.instance.spec.region
    secrets = [
      "credentials"
    ]
  }
}
