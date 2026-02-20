locals {
  output_attributes = {
    name                   = kubernetes_storage_class_v1.storage_class.metadata[0].name
    provisioner            = kubernetes_storage_class_v1.storage_class.storage_provisioner
    volume_type            = var.instance.spec.volume_type
    is_default             = tostring(var.instance.spec.is_default)
    reclaim_policy         = kubernetes_storage_class_v1.storage_class.reclaim_policy
    volume_binding_mode    = kubernetes_storage_class_v1.storage_class.volume_binding_mode
    allow_volume_expansion = tostring(kubernetes_storage_class_v1.storage_class.allow_volume_expansion)
  }

  output_interfaces = {}
}
