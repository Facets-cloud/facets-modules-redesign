# URL Map for routing logic
# Uses computed hosts from rules with domain_prefix

resource "google_compute_url_map" "lb" {
  name    = local.name
  project = local.project_id

  # Default service from first host's highest priority rule
  default_service = local.service_backends[
    [for config in local.rules_grouped_by_host[local.unique_hosts[0]] : config.rule_key
      if config.priority == min([for c in local.rules_grouped_by_host[local.unique_hosts[0]] : c.priority]...)
    ][0]
  ]

  depends_on = [google_compute_backend_service.cloudrun]

  # Host rules: one per unique computed host
  # e.g., example.com, api.example.com, app.example.com
  dynamic "host_rule" {
    for_each = toset(local.unique_hosts)
    content {
      hosts        = [host_rule.value]
      path_matcher = "pm-${substr(md5(host_rule.value), 0, 12)}"
    }
  }

  # Path matchers: one per unique host, with all paths for that host
  dynamic "path_matcher" {
    for_each = local.rules_grouped_by_host
    content {
      name = "pm-${substr(md5(path_matcher.key), 0, 12)}"

      # Default service: highest priority rule (lowest priority number) for this host
      default_service = local.service_backends[
        [for config in path_matcher.value : config.rule_key
          if config.priority == min([for c in path_matcher.value : c.priority]...)
        ][0]
      ]

      # Path rules: all paths for this host, sorted by priority
      dynamic "path_rule" {
        for_each = {
          for idx, config in path_matcher.value :
          "${config.rule_key}-${config.path}" => config
          if config.path != "/"
        }
        content {
          paths   = [path_rule.value.path]
          service = local.service_backends[path_rule.value.rule_key]

          # EXACT match type handling via route_action
          dynamic "route_action" {
            for_each = path_rule.value.path_type == "EXACT" ? [1] : []
            content {
              url_rewrite {
                path_prefix_rewrite = path_rule.value.path
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
