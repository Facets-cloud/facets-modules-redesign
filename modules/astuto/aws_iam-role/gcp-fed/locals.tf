locals {
  name     = lower(var.instance_name)
  spec     = lookup(var.instance, "spec", {})
  advanced = lookup(var.instance, "advanced", {})

  # GCP Federation config
  gcp_federation       = lookup(local.spec, "gcp_federation", {})
  gcp_project_id       = lookup(local.gcp_federation, "gcp_project_id", "")
  create_oidc_provider = lookup(local.gcp_federation, "create_oidc_provider", true)

  # Service accounts for Workload Identity binding
  service_accounts      = lookup(local.gcp_federation, "service_accounts", {})
  service_accounts_list = [for k, v in local.service_accounts : lookup(v, "name", k)]

  # Namespace with fallback
  namespace = lookup(var.instance, "namespace", null) != null ? var.instance.namespace : (
    lookup(var.environment, "namespace", null) != null ? var.environment.namespace : "default"
  )

  # IAM policies
  policies = lookup(local.spec, "policies", {})

  # GCP Service Account name — hard-capped at 30 chars (GCP limit)
  # Format: fed-{env_unique_name}-{resource_name}, trimmed to 30 chars
  gcp_sa_account_id = replace(
    substr("fed-${var.environment.unique_name}-${local.name}", 0, 30),
    "/-+$/", ""
  )

  # GCP Service Account — auto-created, values come from the google_service_account resource
  gcp_service_account_email     = google_service_account.this.email
  gcp_service_account_unique_id = google_service_account.this.unique_id

  # Google OIDC provider ARN (created or referenced)
  google_oidc_provider_arn = local.create_oidc_provider ? aws_iam_openid_connect_provider.google[0].arn : data.aws_iam_openid_connect_provider.google[0].arn
}
