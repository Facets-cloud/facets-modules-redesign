locals {
  spec = var.instance.spec

  # Merge environment cloud tags with spec labels.
  labels = merge(lookup(local.spec, "labels", {}), var.environment.cloud_tags)

  # Merge secrets and variables into one map: GCP secret name -> resolved value.
  # If the same key appears in both, secrets take precedence.
  all_entries = merge(
    lookup(local.spec, "variables", {}),
    lookup(local.spec, "secrets", {})
  )
}
