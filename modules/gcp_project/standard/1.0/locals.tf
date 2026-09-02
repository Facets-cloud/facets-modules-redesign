locals {
  project_labels = merge(
    var.environment.cloud_tags,
    lookup(var.instance.spec, "labels", {})
  )

  deletion_policy   = lookup(var.instance.spec, "deletion_policy", "PREVENT")
  default_sa_action = lookup(var.instance.spec, "default_sa_action", "DEPRIVILEGE")
}
