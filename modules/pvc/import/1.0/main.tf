locals {
  spec = lookup(var.instance, "spec", {})
  pvcs = lookup(local.spec, "pvcs", {})
}

# Adopt existing PersistentVolumeClaims 1:1 from live, keyed by "<namespace>/<name>".
# access_modes, the storage request, storage_class_name, volume_name and selector are IMMUTABLE on a
# PVC: they are set from live exactly or the import force-replaces the claim, which would orphan the
# backing PersistentVolume (and its EBS volume + data). Labels and annotations are reproduced verbatim
# so the k8s-pvc-tagger annotation the controller keys on is preserved; only the controller-injected
# binding annotations are ignored (they are re-populated by k8s, not managed here).
resource "kubernetes_persistent_volume_claim" "pvc" {
  for_each = local.pvcs

  metadata {
    name        = each.value.name
    namespace   = each.value.namespace
    labels      = lookup(each.value, "labels", null)
    annotations = lookup(each.value, "annotations", null)
  }

  spec {
    access_modes       = each.value.access_modes
    storage_class_name = lookup(each.value, "storage_class_name", null)
    volume_name        = lookup(each.value, "volume_name", null)

    resources {
      requests = {
        storage = each.value.storage
      }
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["pv.kubernetes.io/bind-completed"],
      metadata[0].annotations["pv.kubernetes.io/bound-by-controller"],
      metadata[0].annotations["volume.kubernetes.io/storage-provisioner"],
      metadata[0].annotations["volume.beta.kubernetes.io/storage-provisioner"],
    ]
  }
}
