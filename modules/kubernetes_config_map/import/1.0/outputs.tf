locals {
  output_attributes = {
    resource_name      = join(",", sort([for c in kubernetes_config_map_v1.main : "${c.metadata[0].namespace}/${c.metadata[0].name}"]))
    resource_namespace = join(",", distinct([for c in kubernetes_config_map_v1.main : c.metadata[0].namespace]))
  }
  output_interfaces = {}
}
