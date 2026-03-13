# Global forwarding rule for HTTPS
resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${local.name}-https"
  project               = local.project_id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.lb.id
  ip_address            = local.lb_ip_address
  labels                = local.labels
}

# Global forwarding rule for HTTP
resource "google_compute_global_forwarding_rule" "http" {
  count = local.enable_http ? 1 : 0

  name                  = "${local.name}-http"
  project               = local.project_id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.lb[0].id
  ip_address            = local.lb_ip_address
  labels                = local.labels
}
