locals {
  output_interfaces = {}
  output_attributes = {
    project_id  = data.external.gcp_fetch_cloud_secret.result["project"]
    project     = data.external.gcp_fetch_cloud_secret.result["project"] # Keep for backward compatibility
    credentials = sensitive(base64decode(data.external.gcp_fetch_cloud_secret.result["serviceAccountKey"]))
    region      = var.instance.spec.region
    secrets = [
      "credentials"
    ]
  }
}
