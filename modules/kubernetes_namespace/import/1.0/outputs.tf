locals {
  output_interfaces = {}
  output_attributes = {
    resource_name      = join(",", sort([for k, v in kubernetes_namespace_v1.namespace : v.metadata[0].name]))
    resource_namespace = ""
  }
}
