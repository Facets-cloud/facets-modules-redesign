# Backend resources for VM Managed Instance Group (MIG) rules
# Iterates over local.mig_rules — rules with type = "mig"

# Global health checks — one per MIG rule
# Uses protocol/port/path from the rule's health_check block
resource "google_compute_health_check" "mig" {
  for_each = local.mig_rules

  name    = "${local.name}-hc-${substr(md5(each.key), 0, 8)}"
  project = local.project_id

  dynamic "http_health_check" {
    for_each = each.value.health_check.protocol == "HTTP" ? [1] : []
    content {
      port         = each.value.health_check.port
      request_path = each.value.health_check.path
    }
  }

  dynamic "https_health_check" {
    for_each = each.value.health_check.protocol == "HTTPS" ? [1] : []
    content {
      port         = each.value.health_check.port
      request_path = each.value.health_check.path
    }
  }

  dynamic "tcp_health_check" {
    for_each = each.value.health_check.protocol == "TCP" ? [1] : []
    content {
      port = each.value.health_check.port
    }
  }
}

# Backend services — one per MIG rule, backed by the instance group directly
resource "google_compute_backend_service" "mig" {
  for_each = local.mig_rules

  name                            = "${local.name}-${substr(md5(each.key), 0, 8)}"
  project                         = local.project_id
  protocol                        = "HTTP"
  port_name                       = each.value.port_name
  load_balancing_scheme           = "EXTERNAL_MANAGED"
  timeout_sec                     = local.timeout_sec
  enable_cdn                      = local.enable_cdn
  session_affinity                = local.session_affinity
  connection_draining_timeout_sec = local.connection_draining_timeout
  health_checks                   = [google_compute_health_check.mig[each.key].id]

  backend {
    group           = each.value.instance_group_url
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  dynamic "cdn_policy" {
    for_each = local.enable_cdn ? [1] : []
    content {
      cache_mode       = lookup(lookup(local.global_config, "cdn_policy", {}), "cache_mode", "USE_ORIGIN_HEADERS")
      default_ttl      = lookup(lookup(local.global_config, "cdn_policy", {}), "default_ttl", 3600)
      max_ttl          = lookup(lookup(local.global_config, "cdn_policy", {}), "max_ttl", 86400)
      client_ttl       = 3600
      negative_caching = false
    }
  }

  dynamic "iap" {
    for_each = local.enable_iap ? [1] : []
    content {
      enabled              = true
      oauth2_client_id     = lookup(local.global_config, "iap_config", {}).oauth2_client_id
      oauth2_client_secret = lookup(local.global_config, "iap_config", {}).oauth2_client_secret
    }
  }

  security_policy = lookup(local.global_config, "security_policy", null)

  lifecycle {
    create_before_destroy = true
  }
}
