locals {
  private = lookup(var.instance.spec, "private", false)

  ovh_annotations = merge(
    {
      "loadbalancer.ovhcloud.com/flavor" = "small"
    },
    # Private LB: OpenStack/Octavia internal LB — IP only on the private network, no floating IP.
    local.private ? {
      "service.beta.kubernetes.io/openstack-internal-load-balancer" = "true"
    } : {}
  )

  # Private LB → HTTP-01 can't validate (Let's Encrypt can't reach an internal LB), so
  # issue certs via the named DNS-01 ClusterIssuer instead (out-of-band DNS validation;
  # the issuer should use cnameStrategy Follow). Passed through as cluster_issuer_override.
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

  service_annotations      = local.ovh_annotations
  nginx_proxy_extra_config = {}
}
