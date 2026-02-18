# URL Map for routing logic
resource "google_compute_url_map" "lb" {
  name    = local.name
  project = local.project_id

  # Default service from first domain's first rule
  default_service = local.service_backends[
    var.instance.spec.rules[
      var.instance.spec.domains[keys(var.instance.spec.domains)[0]].rules[0]
    ].default_service
  ]

  # Use EXTERNAL_MANAGED for CloudRun serverless backends
  depends_on = [google_compute_backend_service.cloudrun]

  # Host rules: one per domain
  dynamic "host_rule" {
    for_each = var.instance.spec.domains
    content {
      hosts        = [host_rule.value.domain]
      path_matcher = "path-matcher-${replace(host_rule.value.domain, ".", "-")}"
    }
  }

  # Path matchers: one per domain, combining all its rules
  dynamic "path_matcher" {
    for_each = var.instance.spec.domains
    content {
      name = "path-matcher-${replace(path_matcher.value.domain, ".", "-")}"

      # Default service from first rule of this domain
      default_service = local.service_backends[
        var.instance.spec.rules[path_matcher.value.rules[0]].default_service
      ]

      # Path rules: aggregate all paths from all rules for this domain
      dynamic "path_rule" {
        for_each = flatten([
          for rule_name in path_matcher.value.rules : [
            for path_config in lookup(var.instance.spec.rules[rule_name], "paths", []) : {
              path      = path_config.path
              service   = path_config.service
              path_type = lookup(path_config, "path_type", "PREFIX")
              rule_name = rule_name
            }
          ]
        ])
        content {
          paths   = [path_rule.value.path]
          service = local.service_backends[path_rule.value.service]

          # EXACT match type handling
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
