locals {
  spec = var.instance.spec

  # Merge environment cloud tags with spec labels.
  labels = merge(local.spec.labels, var.environment.cloud_tags)

  # Merge secrets and variables into one map: GCP secret name -> resolved value.
  # If the same key appears in both, secrets take precedence.
  all_entries = merge(
    local.spec.variables,
    local.spec.secrets
  )
}
