locals {
  output_interfaces = {}
  output_attributes = {
    subscription_id = sensitive(data.external.azure_fetch_cloud_secret.result["subscription_id"])
    client_id       = sensitive(data.external.azure_fetch_cloud_secret.result["client_id"])
    client_secret   = sensitive(data.external.azure_fetch_cloud_secret.result["client_secret"])
    tenant_id       = sensitive(data.external.azure_fetch_cloud_secret.result["tenant_id"])
    secrets = [
      "client_secret"
    ]
  }
}
