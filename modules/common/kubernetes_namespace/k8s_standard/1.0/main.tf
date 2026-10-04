locals {
  derived = trim(substr(replace(lower(var.environment.name), "/[^a-z0-9-]/", "-"), 0, 63), "-")
  name    = coalesce(var.instance.spec.name, local.derived)
  # Dependent envs on the pod-based path already get this namespace from the platform
  create = local.name != var.environment.namespace
}

resource "kubernetes_namespace_v1" "this" {
  count = local.create ? 1 : 0

  metadata {
    name = local.name
    labels = {
      "app.kubernetes.io/managed-by" = "facets"
      "facets.cloud/environment"     = local.derived
    }
  }

  wait_for_default_service_account = true

  timeouts {
    delete = "15m"
  }

  lifecycle {
    ignore_changes = [metadata[0].labels["kubernetes.io/metadata.name"]]

    precondition {
      condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$", local.name))
      error_message = "Namespace name must be lowercase letters, digits and '-', start and end with a letter or digit, and be at most 63 characters."
    }
  }
}
