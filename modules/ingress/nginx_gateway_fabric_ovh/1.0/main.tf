locals {
  ovh_annotations = {
    "loadbalancer.ovhcloud.com/flavor" = "small"
  }
}

# Call the base utility module
module "nginx_gateway_fabric" {
  source = "github.com/Facets-cloud/facets-utility-modules//nginx_gateway_fabric?ref=3b222c02b481f2517be1a794a2b9b6184e140b19"

  instance      = var.instance
  instance_name = var.instance_name
  environment   = var.environment
  inputs        = var.inputs

  service_annotations      = local.ovh_annotations
  nginx_proxy_extra_config = {}
}
