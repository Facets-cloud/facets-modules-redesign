locals {
  # GCP LB annotations — internal LB with global access when private
  gcp_annotations = lookup(var.instance.spec, "private", false) ? {
    "cloud.google.com/load-balancer-type"                          = "Internal"
    "networking.gke.io/load-balancer-type"                         = "Internal"
    "networking.gke.io/internal-load-balancer-allow-global-access" = "true"
  } : {}

  # Private LB → HTTP-01 can't validate an internal LB; issue certs via the named
  # DNS-01 ClusterIssuer instead (cnameStrategy Follow).
  private                 = lookup(var.instance.spec, "private", false)
  dns01_issuer            = lookup(var.instance.spec, "dns01_cluster_issuer", "")
  cluster_issuer_override = local.private && local.dns01_issuer != "" ? local.dns01_issuer : lookup(var.instance.spec, "cluster_issuer_override", null)

  # Private + DNS-01: one wildcard cert [domain, *.domain] per domain (single DNS-01 challenge)
  # via the listenerset-shim, instead of per-hostname HTTP-01 certs.
  wildcard_tls = local.private && local.dns01_issuer != ""

  modified_instance = merge(var.instance, {
    spec = merge(var.instance.spec, {
      cluster_issuer_override = local.cluster_issuer_override
      wildcard_tls            = local.wildcard_tls
    })
  })
}

# Call the base utility module
module "nginx_gateway_fabric" {
  source = "github.com/Facets-cloud/facets-utility-modules//nginx_gateway_fabric"

  instance      = local.modified_instance
  instance_name = var.instance_name
  environment   = var.environment
  inputs        = var.inputs

  service_annotations      = local.gcp_annotations
  nginx_proxy_extra_config = {}
}
