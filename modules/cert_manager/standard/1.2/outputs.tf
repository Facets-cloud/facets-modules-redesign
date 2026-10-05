locals {
  # dns01-capable issuers, sorted for a stable pick; falls back to the http01 default
  dns01_issuers = sort([
    for k, v in local.environments : v.name
    if length([for s in v.solvers : s if contains(keys(s), "dns01")]) > 0
  ])
  output_attributes = {
    cluster_issuer_http = "letsencrypt-prod-http01"
    cluster_issuer_dns  = length(local.dns01_issuers) > 0 ? local.dns01_issuers[0] : "letsencrypt-prod-http01"
    use_gts             = tostring(anytrue([for k, v in local.environments : startswith(v.name, "gts")]))
    namespace           = local.cert_mgr_namespace
    acme_email          = local.acme_email
  }
  output_interfaces = {
  }
}
