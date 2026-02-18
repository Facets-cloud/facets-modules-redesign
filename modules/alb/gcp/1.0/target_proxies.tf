# HTTPS Target Proxy
resource "google_compute_target_https_proxy" "lb" {
  name             = "${local.name}-https"
  project          = local.project_id
  url_map          = google_compute_url_map.lb.id
  ssl_certificates = local.all_certificates
}

# HTTP Target Proxy (for redirect or direct HTTP)
resource "google_compute_target_http_proxy" "lb" {
  count = local.enable_http ? 1 : 0

  name    = "${local.name}-http"
  project = local.project_id
  url_map = local.http_redirect ? google_compute_url_map.http_redirect[0].id : google_compute_url_map.lb.id
}
