# Serverless Network Endpoint Groups for CloudRun services
resource "google_compute_region_network_endpoint_group" "cloudrun" {
  for_each = toset(local.unique_services)

  name                  = "${local.name}-${substr(md5(each.key), 0, 8)}"
  project               = local.project_id
  region                = local.region
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = each.key
  }
}

# Backend services for each CloudRun service
resource "google_compute_backend_service" "cloudrun" {
  for_each = toset(local.unique_services)

  name                            = "${local.name}-${substr(md5(each.key), 0, 8)}"
  project                         = local.project_id
  protocol                        = "HTTP"
  port_name                       = "http"
  load_balancing_scheme           = "EXTERNAL_MANAGED"
  timeout_sec                     = local.timeout_sec
  enable_cdn                      = local.enable_cdn
  session_affinity                = local.session_affinity
  connection_draining_timeout_sec = local.connection_draining_timeout

  backend {
    group = google_compute_region_network_endpoint_group.cloudrun[each.key].id
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
}

locals {
  # Map service names to backend service IDs
  service_backends = {
    for service in local.unique_services :
    service => google_compute_backend_service.cloudrun[service].id
  }
}
