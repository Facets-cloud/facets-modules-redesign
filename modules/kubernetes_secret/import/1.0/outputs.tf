locals {
  output_attributes = {
    resource_name = join(",", sort([for s in kubernetes_secret_v1.main : "${s.metadata[0].namespace}/${s.metadata[0].name}"]))
  }
  output_interfaces = {}
}
