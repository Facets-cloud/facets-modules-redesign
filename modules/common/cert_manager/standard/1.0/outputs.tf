locals {
  output_attributes = {
    cluster_issuer_http = "letsencrypt-prod-http01"
    namespace           = local.cert_mgr_namespace
    acme_email          = local.acme_email
  }
  output_interfaces = {
  }
}
