locals {
  output_attributes = {
    # Primary cluster issuers for DNS01 and HTTP01 validation
    cluster_issuer_dns  = local.use_gts ? "gts-production" : "letsencrypt-prod"
    cluster_issuer_http = local.use_gts ? "gts-production-http01" : "letsencrypt-prod-http01"

    # All available cluster issuers
    cluster_issuers = {
      dns_staging     = local.use_gts ? null : "letsencrypt-staging"
      dns_production  = local.use_gts ? "gts-production" : "letsencrypt-prod"
      http_staging    = "letsencrypt-staging-http01"
      http_production = local.use_gts ? "gts-production-http01" : "letsencrypt-prod-http01"
    }

    # Configuration details
    namespace          = local.cert_mgr_namespace
    use_gts            = local.use_gts
    has_dns_validation = local.has_external_dns
    dns_provider       = local.has_external_dns ? local.external_dns.provider : null

    # Helm release information
    helm_release_name = helm_release.cert_manager.name
    helm_release_id   = helm_release.cert_manager.id
  }
  output_interfaces = {}
}