locals {
  output_attributes = {
    cluster_issuer_http = "letsencrypt-prod-http01"
    namespace           = local.cert_mgr_namespace
  }
  output_interfaces = {
  }
}
