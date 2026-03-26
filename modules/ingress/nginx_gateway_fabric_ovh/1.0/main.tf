locals {
  ovh_annotations = {
    "loadbalancer.ovhcloud.com/flavor" = "small"
  }
}

# Call the base utility module
module "nginx_gateway_fabric" {
  source = "github.com/Facets-cloud/facets-utility-modules//nginx_gateway_fabric"

  instance      = var.instance
  instance_name = var.instance_name
  environment   = var.environment
  inputs        = var.inputs

  service_annotations      = local.ovh_annotations
  nginx_proxy_extra_config = {}
}
