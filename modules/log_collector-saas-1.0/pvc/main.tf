resource "kubernetes_persistent_volume_claim" "pvc" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels = merge(
      {
      provisioned_for = var.provisioned_for
      instance_name   = var.instance_name
      resource_type   = var.kind
      resourceType = var.kind
      resourceName = var.instance_name
      }, 
      var.additional_labels
    )
    annotations = merge(var.annotations, { "k8s-pvc-tagger/tags" = jsonencode(merge({resource_type = var.kind, resource_name = var.instance_name}, var.cloud_tags)) })
  }
  spec {
    access_modes = var.access_modes
    storage_class_name = var.storage_class_name
    resources {
      requests = {
        storage = var.volume_size
      }
    }
  }
  wait_until_bound = false
  lifecycle {
    ignore_changes = [metadata[0].name]
    prevent_destroy = true
  }
}