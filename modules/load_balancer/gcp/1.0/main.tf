locals {
  spec        = var.instance.spec
  ca_attrs    = var.inputs.cloud_account.attributes
  gcp_project = local.ca_attrs.project_id

  net_attrs = var.inputs.network_details.attributes
  network   = lookup(local.net_attrs, "vpc_id", "default")

  lb_name = var.instance_name

  # Import-only pins (empty for greenfield).
  imports_obj = lookup(local.spec, "imports", {})

  # IP: present pin = adopt existing global address (referenced only, NOT created/imported);
  # empty = greenfield creates a google_compute_global_address.
  ip_address_import = lookup(local.imports_obj, "ip_address", "")
  create_address    = local.ip_address_import == ""

  # SSL certs: present pins = reference existing certs (e.g. self-managed wildcard — never created);
  # empty = greenfield managed cert from domains_json.
  ssl_cert_names = jsondecode(lookup(local.imports_obj, "ssl_certificate_names", "[]"))
  domains        = jsondecode(lookup(local.spec, "domains_json", "[]"))
  create_cert    = length(local.ssl_cert_names) == 0 && length(local.domains) > 0

  # Names: pinned live name else derived from the Facets resource name.
  fr_name               = lookup(local.imports_obj, "forwarding_rule_name", "") != "" ? local.imports_obj.forwarding_rule_name : local.lb_name
  https_proxy_name      = lookup(local.imports_obj, "https_proxy_name", "") != "" ? local.imports_obj.https_proxy_name : "${local.lb_name}-target-proxy"
  url_map_name          = lookup(local.imports_obj, "url_map_name", "") != "" ? local.imports_obj.url_map_name : local.lb_name
  backend_service_name  = lookup(local.imports_obj, "backend_service_name", "") != "" ? local.imports_obj.backend_service_name : local.lb_name
  health_check_name     = lookup(local.imports_obj, "health_check_name", "") != "" ? local.imports_obj.health_check_name : "${local.lb_name}-hc"
  instance_group_name   = lookup(local.imports_obj, "instance_group_name", "") != "" ? local.imports_obj.instance_group_name : "${local.lb_name}-group"
  redirect_fr_name      = lookup(local.imports_obj, "redirect_fr_name", "") != "" ? local.imports_obj.redirect_fr_name : "${local.lb_name}-redirect"
  http_proxy_name       = lookup(local.imports_obj, "http_proxy_name", "") != "" ? local.imports_obj.http_proxy_name : "${local.lb_name}-http-proxy"
  redirect_url_map_name = lookup(local.imports_obj, "redirect_url_map_name", "") != "" ? local.imports_obj.redirect_url_map_name : "${local.lb_name}-redirect"

  # Backend members: the selected service's VM self_links (full URLs). try() tolerates the
  # backend_service field being an empty/unresolved value (e.g. the referenced service not yet
  # applied, so its outputs are unknown) — it then degrades to [] and the UIG `instances` are
  # ignore_changed (live members read into state) so adoption stays 0-change regardless.
  backend_self_links = try(local.spec.backend_service.self_links, [])

  # UIG zone is ForceNew, so it must be deterministic even when backend_self_links is unknown
  # (referenced service not applied). Resolution order: explicit pin (imports.instance_group_zone)
  # -> derive from the first member self_link (.../zones/<zone>/instances/<name>) -> region default.
  uig_zone = (
    lookup(local.imports_obj, "instance_group_zone", "") != "" ? local.imports_obj.instance_group_zone :
    length(local.backend_self_links) > 0 ? element(reverse(split("/", local.backend_self_links[0])), 2) :
    "${lookup(local.net_attrs, "region", "us-central1")}-a"
  )

  port_name_final = lookup(local.spec, "backend_port_name", "") != "" ? local.spec.backend_port_name : "http"

  # Health check params.
  hc          = lookup(local.spec, "health_check", {})
  hc_protocol = lookup(local.hc, "protocol", "HTTP")
  hc_port     = lookup(local.hc, "port", 80)
  hc_path     = lookup(local.hc, "request_path", "/")

  # Health-check reference mode. Some stacks BORROW another stack's health check (live HCs are shared
  # across LBs). If imports.health_check_self_link is pinned, the backend references it and NO HC
  # resource is created/imported (avoids two LB resources co-owning one cloud HC). Empty = this stack
  # owns its HC (create greenfield / import on adoption).
  hc_self_link_import = lookup(local.imports_obj, "health_check_self_link", "")
  create_hc           = local.hc_self_link_import == ""
  hc_self_link_final  = local.create_hc ? google_compute_health_check.hc[0].self_link : local.hc_self_link_import

  # Resolved frontend IP + cert set.
  ip_address_final = local.create_address ? google_compute_global_address.ip[0].address : local.ip_address_import
  ssl_certs_final  = local.create_cert ? [google_compute_managed_ssl_certificate.cert[0].self_link] : local.ssl_cert_names

  # Greenfield routing into the url-map: [{host[], path_rules:[{paths[], service}]}]. Empty = default only.
  routing_rules = jsondecode(lookup(local.spec, "routing_rules_json", "[]"))
}

# ---------------------------------------------------------------------------
# Frontend IP — greenfield only. Adoption references the pinned imports.ip_address (the existing
# global address stays unmanaged — never imported here per the read-only-import contract).
# ---------------------------------------------------------------------------
resource "google_compute_global_address" "ip" {
  count   = local.create_address ? 1 : 0
  name    = local.lb_name
  project = local.gcp_project
}

# ---------------------------------------------------------------------------
# Managed SSL cert — greenfield only (from domains_json). Adoption references imports.ssl_certificate_names
# (a self-managed wildcard is referenced, never created/imported).
# ---------------------------------------------------------------------------
resource "google_compute_managed_ssl_certificate" "cert" {
  count   = local.create_cert ? 1 : 0
  name    = "${local.lb_name}-cert"
  project = local.gcp_project
  managed {
    domains = local.domains
  }
}

# ---------------------------------------------------------------------------
# Health check.
# ---------------------------------------------------------------------------
resource "google_compute_health_check" "hc" {
  count   = local.create_hc ? 1 : 0
  name    = local.health_check_name
  project = local.gcp_project

  dynamic "http_health_check" {
    for_each = local.hc_protocol == "HTTP" ? [1] : []
    content {
      port         = local.hc_port
      request_path = local.hc_path
    }
  }
  dynamic "https_health_check" {
    for_each = local.hc_protocol == "HTTPS" ? [1] : []
    content {
      port         = local.hc_port
      request_path = local.hc_path
    }
  }
  dynamic "tcp_health_check" {
    for_each = local.hc_protocol == "TCP" ? [1] : []
    content {
      port = local.hc_port
    }
  }

  lifecycle {
    # log_config is a provider-computed block (live reads enable=false); leaving it unset reads as a
    # diff. Hand-rolled HCs also carry non-default tuning + a description not modeled in spec:
    #   check_interval_sec / unhealthy_threshold : live overrides (e.g. 10/10) vs provider defaults.
    #   description                              : free-text on the live HC.
    ignore_changes = [log_config, check_interval_sec, unhealthy_threshold, timeout_sec, description]
  }
}

# ---------------------------------------------------------------------------
# Unmanaged instance group (UIG) — the backend members are the service's VMs. Zonal; zone derived
# from the member self_link. named_port lets the backend service target by name.
# ---------------------------------------------------------------------------
resource "google_compute_instance_group" "uig" {
  name      = local.instance_group_name
  project   = local.gcp_project
  zone      = local.uig_zone
  instances = local.backend_self_links

  named_port {
    name = local.port_name_final
    port = local.spec.backend_port
  }

  lifecycle {
    # network    : provider-computed from the member instances (live stores the full network URL).
    # instances  : the live membership reads into state; member self_links may be unknown at plan
    #              (referenced service not yet applied) and order is non-deterministic. Greenfield
    #              still sets instances at create; drift on membership thereafter is not managed
    #              here (the service resource owns its VMs). Ignoring keeps adoption 0-change.
    # description is ForceNew on an instance group — a hand-rolled UIG carries one, so leaving it
    # unset would DESTROY+recreate the live group. Ignore it for 0-change adoption.
    # named_port: some live IGs expose extra named ports (e.g. tableau's tableau-ports:8850) the
    # module doesn't model; leaving them unset would remove them. Ignore so adoption preserves live
    # (greenfield still sets the primary named_port at create).
    ignore_changes = [network, instances, description, named_port]
  }
}

# ---------------------------------------------------------------------------
# Backend service.
# ---------------------------------------------------------------------------
resource "google_compute_backend_service" "bs" {
  name                  = local.backend_service_name
  project               = local.gcp_project
  protocol              = local.spec.backend_protocol
  port_name             = local.port_name_final
  timeout_sec           = local.spec.timeout_sec
  load_balancing_scheme = local.spec.lb_scheme
  health_checks         = [local.hc_self_link_final]

  backend {
    group           = google_compute_instance_group.uig.self_link
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1
    max_utilization = 0.8
  }

  lifecycle {
    # All provider-computed blocks whose live values are GCP defaults / out-of-band settings not
    # modeled here. Leaving them unset reads as removal and would otherwise force a diff on import:
    #   cdn_policy / iap / log_config : computed sub-blocks present on the live BS (CDN+IAP disabled).
    #   locality_lb_policy            : computed (ROUND_ROBIN) for EXTERNAL_MANAGED.
    #   ip_address_selection_policy   : computed (IPV4_ONLY).
    #   connection_draining_timeout_sec: live 300 == provider default but reads as computed here.
    ignore_changes = [
      cdn_policy,
      iap,
      log_config,
      locality_lb_policy,
      ip_address_selection_policy,
      connection_draining_timeout_sec,
      # Cloud Armor policy attached out-of-band (live: my-armor-policy) — not modeled.
      security_policy,
      # Cloud CDN enabled on some live backends; CDN config is a separate concern, not modeled here.
      enable_cdn,
      compression_mode,
      # Free-text description on hand-rolled backends.
      description,
      # Verification headers (e.g. x-glb-verify:<token>) injected out-of-band on some backends —
      # secret-ish, kept live and out of the blueprint rather than modeled.
      custom_request_headers,
      custom_response_headers,
    ]
  }
}

# ---------------------------------------------------------------------------
# URL map — default_service is the backend; greenfield host/path rules from routing_rules_json.
# host_rule + path_matcher are ignore_changed: adopted stacks may carry live GKE/spill path rules we
# DELIBERATELY do not model (model VM-default only, never strip live routing). Greenfield still
# applies routing_rules_json at create; drift on it thereafter is not managed.
# ---------------------------------------------------------------------------
resource "google_compute_url_map" "um" {
  name            = local.url_map_name
  project         = local.gcp_project
  default_service = google_compute_backend_service.bs.self_link

  dynamic "host_rule" {
    for_each = local.routing_rules
    content {
      hosts        = host_rule.value.host
      path_matcher = "matcher-${host_rule.key}"
    }
  }
  dynamic "path_matcher" {
    for_each = local.routing_rules
    content {
      name            = "matcher-${path_matcher.key}"
      default_service = google_compute_backend_service.bs.self_link
      dynamic "path_rule" {
        for_each = lookup(path_matcher.value, "path_rules", [])
        content {
          paths   = path_rule.value.paths
          service = google_compute_backend_service.bs.self_link
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [host_rule, path_matcher]
  }
}

# ---------------------------------------------------------------------------
# Target HTTPS proxy — url_map + ssl_certificates (referenced existing or greenfield managed).
# ---------------------------------------------------------------------------
resource "google_compute_target_https_proxy" "https" {
  name             = local.https_proxy_name
  project          = local.gcp_project
  url_map          = google_compute_url_map.um.self_link
  ssl_certificates = local.ssl_certs_final

  lifecycle {
    # ssl_policy (live my-ssl-policy), quic_override, http_keep_alive_timeout_sec, tls_early_data
    # are out-of-band / provider-computed and not modeled in spec — ignore for 0-change adoption.
    ignore_changes = [ssl_policy, quic_override, http_keep_alive_timeout_sec, tls_early_data]
  }
}

# ---------------------------------------------------------------------------
# Global forwarding rule (frontend :port).
# ---------------------------------------------------------------------------
resource "google_compute_global_forwarding_rule" "fr" {
  name                  = local.fr_name
  project               = local.gcp_project
  port_range            = tostring(local.spec.port)
  load_balancing_scheme = local.spec.lb_scheme
  target                = google_compute_target_https_proxy.https.self_link
  ip_address            = local.ip_address_final

  lifecycle {
    # description AND ip_version are ForceNew on a forwarding rule — hand-rolled FRs set ip_version
    # explicitly (IPV4); leaving it unset reads as IPV4->null and would REPLACE the live FR. Ignore both.
    ignore_changes = [labels, description, ip_version]
  }
}

# ---------------------------------------------------------------------------
# Optional :80 -> :443 redirect stack.
# ---------------------------------------------------------------------------
resource "google_compute_url_map" "redirect" {
  count   = local.spec.redirect_http ? 1 : 0
  name    = local.redirect_url_map_name
  project = local.gcp_project

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }

  lifecycle {
    # GCP auto-generates a description on these redirect url-maps; and some live redirects carry a
    # host_redirect (e.g. app.example.com) the module's default_url_redirect doesn't model. Ignore both
    # the description and the whole default_url_redirect block so adoption preserves live (greenfield
    # still sets the https-redirect at create).
    ignore_changes = [description, default_url_redirect]
  }
}

resource "google_compute_target_http_proxy" "http" {
  count   = local.spec.redirect_http ? 1 : 0
  name    = local.http_proxy_name
  project = local.gcp_project
  url_map = google_compute_url_map.redirect[0].self_link
}

resource "google_compute_global_forwarding_rule" "fr_redirect" {
  count                 = local.spec.redirect_http ? 1 : 0
  name                  = local.redirect_fr_name
  project               = local.gcp_project
  port_range            = "80"
  load_balancing_scheme = local.spec.lb_scheme
  target                = google_compute_target_http_proxy.http[0].self_link
  ip_address            = local.ip_address_final

  lifecycle {
    # description AND ip_version are ForceNew on a forwarding rule — hand-rolled FRs set ip_version
    # explicitly (IPV4); leaving it unset reads as IPV4->null and would REPLACE the live FR. Ignore both.
    ignore_changes = [labels, description, ip_version]
  }
}
