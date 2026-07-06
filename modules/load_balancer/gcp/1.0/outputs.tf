locals {
  # @custom/load_balancer output type.
  output_attributes = {
    ip_address                = local.ip_address_final
    name                      = local.lb_name
    url_map_self_link         = google_compute_url_map.um.self_link
    forwarding_rule_self_link = google_compute_global_forwarding_rule.fr.self_link
    backend_service_self_link = google_compute_backend_service.bs.self_link
  }
  output_interfaces = {}
}
