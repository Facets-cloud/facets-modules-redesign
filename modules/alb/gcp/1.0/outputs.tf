locals {
  output_attributes = {
    lb_name          = local.name
    lb_ip_address    = local.lb_ip_address
    lb_ip_name       = local.lb_ip_name
    url_map_id       = google_compute_url_map.lb.id
    https_proxy_id   = google_compute_target_https_proxy.lb.id
    http_proxy_id    = local.enable_http ? google_compute_target_http_proxy.lb[0].id : ""
    domains          = [for k, v in var.instance.spec.domains : v.domain]
    certificates     = keys(local.managed_certs)
    backend_services = keys(local.service_backends)
    https_url        = "https://${values(var.instance.spec.domains)[0].domain}"
    http_url         = local.enable_http ? "http://${values(var.instance.spec.domains)[0].domain}" : ""
  }

  output_interfaces = {
    https = {
      host       = values(var.instance.spec.domains)[0].domain
      port       = "443"
      protocol   = "https"
      url        = "https://${values(var.instance.spec.domains)[0].domain}"
      ip_address = local.lb_ip_address
    }
    http = local.enable_http ? {
      host       = values(var.instance.spec.domains)[0].domain
      port       = "80"
      protocol   = "http"
      url        = "http://${values(var.instance.spec.domains)[0].domain}"
      ip_address = local.lb_ip_address
    } : null
  }
}
