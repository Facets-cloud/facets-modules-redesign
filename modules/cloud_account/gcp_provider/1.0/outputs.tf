locals {
  # serviceAccountKey holds a key, a WIF external_account config, or, for accounts linked by
  # service-account impersonation, an "impersonated_service_account" marker with no source
  # credential. For the marker the provider uses the release pod's own identity (ADC) and
  # impersonates the account's service account; everything else is passed through unchanged.
  credential_json = base64decode(data.external.gcp_fetch_cloud_secret.result["serviceAccountKey"])
  credential      = jsondecode(local.credential_json)
  impersonated    = try(local.credential.type, "") == "impersonated_service_account"
  impersonate_sa  = local.impersonated ? regex("serviceAccounts/([^:]+):generateAccessToken$", local.credential.service_account_impersonation_url)[0] : null

  output_interfaces = {}
  output_attributes = {
    project_id                  = data.external.gcp_fetch_cloud_secret.result["project"]
    project                     = data.external.gcp_fetch_cloud_secret.result["project"] # Keep for backward compatibility
    credentials                 = sensitive(local.impersonated ? null : local.credential_json)
    impersonate_service_account = local.impersonate_sa
    region                      = var.instance.spec.region
    secrets = [
      "credentials"
    ]
  }
}
