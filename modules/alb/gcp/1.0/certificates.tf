# Managed SSL certificates
resource "google_compute_managed_ssl_certificate" "cert" {
  for_each = local.managed_certs

  name    = each.key
  project = local.project_id

  managed {
    domains = [each.value]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Data source for existing certificates
data "google_compute_ssl_certificate" "existing" {
  for_each = {
    for domain, cert_config in local.certificates :
    domain => cert_config.cert_name
    if !cert_config.create_managed && cert_config.cert_name != ""
  }

  name    = each.value
  project = local.project_id
}

locals {
  # Map domains to certificate self_links
  domain_certificates = merge(
    # Managed certificates
    {
      for domain, cert_config in local.certificates :
      domain => google_compute_managed_ssl_certificate.cert[cert_config.cert_name].id
      if cert_config.create_managed
    },
    # Existing certificates
    {
      for domain, cert_config in local.certificates :
      domain => data.google_compute_ssl_certificate.existing[domain].id
      if !cert_config.create_managed && cert_config.cert_name != ""
    }
  )

  # All unique certificate IDs for the target proxy
  all_certificates = distinct(values(local.domain_certificates))
}
