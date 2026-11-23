locals {
  # GCP LB annotations — internal LB with global access when private
  gcp_annotations = lookup(var.instance.spec, "private", false) ? {
    "cloud.google.com/load-balancer-type"                          = "Internal"
    "networking.gke.io/load-balancer-type"                         = "Internal"
    "networking.gke.io/internal-load-balancer-allow-global-access" = "true"
  } : {}
}

# Call the base utility module
module "nginx_gateway_fabric" {
  source = "github.com/Facets-cloud/facets-utility-modules//nginx_gateway_fabric?ref=3b222c02b481f2517be1a794a2b9b6184e140b19"

  instance      = var.instance
  instance_name = var.instance_name
  environment   = var.environment
  inputs        = var.inputs

  service_annotations      = local.gcp_annotations
  nginx_proxy_extra_config = {}
}
