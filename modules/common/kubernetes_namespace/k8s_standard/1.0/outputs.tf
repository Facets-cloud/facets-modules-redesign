locals {
  output_attributes = {
    name = kubernetes_namespace_v1.this.metadata[0].name
  }

  output_interfaces = {}
}
