locals {
  output_attributes = {
    name                   = kubernetes_storage_class_v1.efs_storage_class.metadata[0].name
    provisioner            = kubernetes_storage_class_v1.efs_storage_class.storage_provisioner
    volume_type            = "efs"
    is_default             = "false"
    reclaim_policy         = kubernetes_storage_class_v1.efs_storage_class.reclaim_policy
    volume_binding_mode    = kubernetes_storage_class_v1.efs_storage_class.volume_binding_mode
    allow_volume_expansion = "false"
  }

  output_interfaces = {}
}
