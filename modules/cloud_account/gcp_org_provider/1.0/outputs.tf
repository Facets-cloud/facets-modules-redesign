locals {
  output_interfaces = {}
  output_attributes = {
    credentials     = sensitive(base64decode(data.external.gcp_fetch_cloud_secret.result["serviceAccountKey"]))
    project_id      = data.external.gcp_fetch_cloud_secret.result["project"]
    org_id          = var.instance.spec.org_id
    org_name        = "organizations/${var.instance.spec.org_id}"
    billing_account = var.instance.spec.billing_account
    # NOTE: `quota_project` is declared `optional(string)` in variables.tf, so when the
    # operator omits it Terraform materialises the attribute as null rather than absent.
    # lookup() therefore finds the key and returns null — it does NOT fall back to the
    # default. coalesce() is what actually applies the fallback here.
    # This matters: user_project_override = true with a null billing_project is the exact
    # combination that makes Org Policy v2 / Resource Manager v3 return 403s.
    quota_project = coalesce(
      try(var.instance.spec.quota_project, null),
      data.external.gcp_fetch_cloud_secret.result["project"]
    )
    user_project_override = true
    region                = var.instance.spec.region
    secrets = [
      "credentials"
    ]
  }
}
