locals {
  spec            = lookup(var.instance, "spec", {})
  storage_classes = lookup(local.spec, "storage_classes", {})
}

# Cluster-scoped StorageClasses.
# NOTE: storage_provisioner, parameters, reclaim_policy and volume_binding_mode are IMMUTABLE — when
# adopting an existing StorageClass they must match live exactly or the import forces destroy+recreate.
resource "kubernetes_storage_class_v1" "storage_class" {
  for_each = local.storage_classes

  metadata {
    name        = each.key
    labels      = lookup(lookup(each.value, "metadata", {}), "labels", null)
    annotations = lookup(lookup(each.value, "metadata", {}), "annotations", null)
  }

  storage_provisioner    = each.value.provisioner
  parameters             = lookup(each.value, "parameters", null)
  reclaim_policy         = lookup(each.value, "reclaim_policy", "Delete")
  volume_binding_mode    = lookup(each.value, "volume_binding_mode", "Immediate")
  allow_volume_expansion = lookup(each.value, "allow_volume_expansion", true)
  mount_options          = lookup(each.value, "mount_options", null)
}
