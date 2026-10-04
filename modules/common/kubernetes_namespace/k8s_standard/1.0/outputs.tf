locals {
  output_attributes = {
    name = local.create ? kubernetes_namespace_v1.this[0].metadata[0].name : local.name
  }

  output_interfaces = {}
}
