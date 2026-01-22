locals {
  output_attributes = {
    config_name      = "${local.name}-config"
    namespace        = local.namespace
    receiver_count   = tostring(local.receiver_count)
    route_count      = tostring(local.route_count)
    enabled_channels = local.enabled_channels
  }

  output_interfaces = {}
}
