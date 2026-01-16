locals {
  output_attributes = {
    gateway_api_version    = local.gateway_api_version
    crds_installed         = true
    experimental_installed = lookup(var.instance.spec, "install_experimental", false)
  }
  output_interfaces = {}
}
