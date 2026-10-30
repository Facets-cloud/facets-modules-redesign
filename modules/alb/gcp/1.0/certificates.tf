# Managed SSL certificates - one per host (computed from domain_prefix)
# Creates certificates for example.com, api.example.com, app.example.com, etc.

resource "google_compute_managed_ssl_certificate" "cert" {
  for_each = local.managed_certs

  name    = each.value.cert_name
  project = local.project_id

  managed {
    domains = [each.value.domain]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Data source for existing certificates
data "google_compute_ssl_certificate" "existing" {
  for_each = local.existing_certs

  name    = each.value
  project = local.project_id
}

# Data source for wildcard certificates
data "google_compute_ssl_certificate" "wildcard" {
  for_each = local.wildcard_certs

  name    = each.value
  project = local.project_id
}

locals {
  # Map hosts to certificate self_links
  host_certificates = merge(
    # Managed certificates (auto/managed mode)
    {
      for host, config in local.managed_certs :
      host => google_compute_managed_ssl_certificate.cert[host].id
    },
    # Existing certificates
    {
      for host, cert_name in local.existing_certs :
      host => data.google_compute_ssl_certificate.existing[host].id
    },
    # Wildcard certificates
    {
      for host, cert_name in local.wildcard_certs :
      host => data.google_compute_ssl_certificate.wildcard[host].id
    }
  )

  # All unique certificate IDs for the target proxy
  all_certificates = distinct(values(local.host_certificates))
}
