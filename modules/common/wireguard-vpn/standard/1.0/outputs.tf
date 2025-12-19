locals {
  output_attributes = {
    name        = var.instance_name
    namespace   = local.namespace
    api_version = "vpn.wireguard-operator.io/v1alpha1"
    kind        = "Wireguard"
  }
  output_interfaces = {
  }
}