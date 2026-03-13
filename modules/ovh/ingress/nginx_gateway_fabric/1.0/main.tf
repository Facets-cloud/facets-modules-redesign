locals {
  # OVH has no cloud-specific LB annotations
  ovh_annotations = {}
}

# Call the base utility module
module "nginx_gateway_fabric" {
  source = "github.com/Facets-cloud/facets-utility-modules//nginx_gateway_fabric?ref=nginx-gateway-fabric-base"

  instance      = var.instance
  instance_name = var.instance_name
  environment   = var.environment
  inputs        = var.inputs

  service_annotations      = local.ovh_annotations
  nginx_proxy_extra_config = {}
}
