locals {
  # serviceAccountKey is empty for impersonation accounts; null lets the provider use ADC.
  # lookup() keeps this module working against secret-fetcher versions without the new key.
  key         = data.external.gcp_fetch_cloud_secret.result["serviceAccountKey"]
  impersonate = lookup(data.external.gcp_fetch_cloud_secret.result, "impersonate_service_account", "")

  output_interfaces = {}
  output_attributes = {
    project_id                  = data.external.gcp_fetch_cloud_secret.result["project"]
    project                     = data.external.gcp_fetch_cloud_secret.result["project"] # Keep for backward compatibility
    credentials                 = sensitive(local.key == "" ? null : base64decode(local.key))
    impersonate_service_account = local.impersonate == "" ? null : local.impersonate
    region                      = var.instance.spec.region
    secrets = [
      "credentials"
    ]
  }
}
