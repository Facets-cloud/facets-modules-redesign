# Output contract: @facets/any_cloud_config_map
# Consumers mount by name+namespace; no network endpoint.
locals {
  output_attributes = {
    cloud_provider  = local.cloud_provider
    config_map_name = kubernetes_config_map_v1.this.metadata[0].name
    namespace       = kubernetes_config_map_v1.this.metadata[0].namespace
    data_keys       = local.data_keys
  }

  # A ConfigMap exposes no network endpoint.
  output_interfaces = {}
}

