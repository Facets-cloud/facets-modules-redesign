# Output contract: @facets/any_cloud_account
# Nested aws{} / gcp{} wrappers: only the selected cloud is populated; the
# inactive one keeps the SAME keys with null values so it stays inert.

locals {
  output_attributes = {
    cloud_provider = var.instance.spec.cloud_provider

    # --- AWS wrapper ---
    # Populated when AWS selected; else explicit null-valued keys (NOT {}). A literal {} loses its
    # type across the module->root boundary, so the root aws provider block referencing
    # attributes.aws.role_arn errors ("object with no attributes") in a GCP env. null role_arn ->
    # the aws provider SKIPS assume (warning only, no STS call).
    aws = local.is_aws ? {
      role_arn    = sensitive(data.external.aws_fetch_cloud_secret[0].result["iamRole"])
      external_id = sensitive(data.external.aws_fetch_cloud_secret[0].result["externalId"])
      region      = var.instance.spec.aws_region
      } : {
      role_arn    = null
      external_id = null
      region      = null
    }

    # --- GCP wrapper ---
    # Populated when GCP selected. When inactive it CANNOT be {} — the google provider needs a
    # non-null access_token (stub) to configure without ADC/key-parse; credentials stays null.
    gcp = local.is_gcp ? {
      project_id   = data.external.gcp_fetch_cloud_secret[0].result["project"]
      credentials  = sensitive(base64decode(data.external.gcp_fetch_cloud_secret[0].result["serviceAccountKey"]))
      access_token = null
      region       = var.instance.spec.gcp_region
      } : {
      project_id   = null
      credentials  = null
      access_token = "inactive-cloud-stub-token"
      region       = null
    }
  }
  output_interfaces = {
  }
}

