# Dedicated name for the service account - GCP enforces a 30-char hard limit on account IDs
module "sa_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 30
  resource_name   = var.instance_name
  resource_type   = "sa"
  globally_unique = false
}

locals {
  sa_name = replace(module.sa_name.name, "_", "-")
}

# Service account for the Cloud Run service
resource "google_service_account" "this" {
  account_id   = local.sa_name
  display_name = "Cloud Run service account for ${local.service_name}"
  project      = local.project_id
}

# Default role: allow the service account to read secrets from Secret Manager
resource "google_project_iam_member" "secret_accessor" {
  project = local.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.this.email}"
}

# Additional IAM roles from spec.cloud_permissions.gcp.roles
resource "google_project_iam_member" "cloud_permissions" {
  for_each = {
    for key, val in try(var.instance.spec.cloud_permissions.gcp.roles, {}) : key => val
  }

  project = local.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.this.email}"

  dynamic "condition" {
    for_each = try(each.value.condition, null) != null ? [each.value.condition] : []
    content {
      title       = condition.value.title
      expression  = condition.value.expression
      description = try(condition.value.description, null)
    }
  }
}
