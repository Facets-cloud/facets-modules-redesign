locals {
  spec = var.instance.spec

  # Merge environment cloud tags with spec labels.
  labels = merge(lookup(local.spec, "labels", {}), var.environment.cloud_tags)

  # Map of GCP secret name -> resolved value.
  all_entries = lookup(local.spec, "secrets", {})
}
