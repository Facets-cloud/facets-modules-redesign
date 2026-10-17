locals {
  output_interfaces = {}
  output_attributes = {
    # StorageClasses are cluster-scoped, so there is no namespace; the name lists the managed set.
    resource_name      = join(",", sort([for k, v in kubernetes_storage_class_v1.storage_class : v.metadata[0].name]))
    resource_namespace = ""
  }
}
