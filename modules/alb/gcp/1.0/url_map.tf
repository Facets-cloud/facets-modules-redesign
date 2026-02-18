# URL Map for routing logic
resource "google_compute_url_map" "lb" {
  name            = local.name
  project         = local.project_id
  default_service = local.service_backends[values(var.instance.spec.domains)[0].default_service]

  # Use EXTERNAL_MANAGED for CloudRun serverless backends
  depends_on = [google_compute_backend_service.cloudrun]

  dynamic "host_rule" {
    for_each = var.instance.spec.domains
    content {
      hosts        = [host_rule.value.domain]
      path_matcher = "path-matcher-${replace(host_rule.value.domain, ".", "-")}"
    }
  }

  dynamic "path_matcher" {
    for_each = var.instance.spec.domains
    content {
      name            = "path-matcher-${replace(path_matcher.value.domain, ".", "-")}"
      default_service = local.service_backends[path_matcher.value.default_service]

      dynamic "path_rule" {
        for_each = lookup(path_matcher.value, "paths", {})
        content {
          paths   = [path_rule.key]
          service = local.service_backends[path_rule.value.service]

          dynamic "route_action" {
            for_each = path_rule.value.path_type == "EXACT" ? [1] : []
            content {
              url_rewrite {
                path_prefix_rewrite = path_rule.key
              }
            }
          }
        }
      }
    }
  }
}

# URL Map for HTTP to HTTPS redirect (if enabled)
resource "google_compute_url_map" "http_redirect" {
  count = local.enable_http && local.http_redirect ? 1 : 0

  name    = "${local.name}-http-redirect"
  project = local.project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}
