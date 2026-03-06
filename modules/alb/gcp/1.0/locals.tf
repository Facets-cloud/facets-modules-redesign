locals {
  name       = module.name.name
  project_id = var.inputs.gcp_cloud_account.attributes.project_id
  region     = var.inputs.gcp_cloud_account.attributes.region

  # ─── Rule Classification ────────────────────────────────────────────────────
  # Separate global rules (no domain_key) from domain-specific rules (has domain_key)

  # Global rules: apply to ALL domains
  global_rules = {
    for rule_key, rule in var.instance.spec.rules :
    rule_key => rule
    if lookup(rule, "domain_key", "") == ""
  }

  # Domain-specific rules: apply only to their specified domain
  domain_specific_rules = {
    for rule_key, rule in var.instance.spec.rules :
    rule_key => rule
    if lookup(rule, "domain_key", "") != ""
  }

  # ─── Rules by Host Computation ──────────────────────────────────────────────
  # Compute the final host for each rule×domain combination
  # Similar to traefik/nginx ingress pattern

  # Global rules × all domains
  global_rules_by_host = merge([
    for domain_key, domain_config in var.instance.spec.domains : {
      for rule_key, rule in local.global_rules :
      "${rule_key}-${domain_key}" => {
        host = (
          # Rule has wildcard prefix → use bare domain
          lookup(rule, "domain_prefix", "*") == "*" ? domain_config.domain :
          # Rule prefix matches an equivalent_prefix → use bare domain
          contains(lookup(domain_config, "equivalent_prefixes", []), lookup(rule, "domain_prefix", "")) ? domain_config.domain :
          # Rule has empty prefix → use bare domain
          lookup(rule, "domain_prefix", "") == "" ? domain_config.domain :
          # Normal case → prefix.domain (subdomain)
          "${lookup(rule, "domain_prefix", "*")}.${domain_config.domain}"
        )
        rule        = rule
        rule_key    = rule_key
        domain_key  = domain_key
        domain      = domain_config.domain
        service     = rule.service
        path        = lookup(rule, "path", "/")
        path_type   = lookup(rule, "path_type", "PREFIX")
        priority    = lookup(rule, "priority", 100)
        certificate = lookup(domain_config, "certificate", {})
      }
    }
  ]...)

  # Domain-specific rules × their specific domain only
  domain_specific_rules_by_host = {
    for rule_key, rule in local.domain_specific_rules :
    rule_key => {
      host = (
        # Rule has wildcard prefix → use bare domain
        lookup(rule, "domain_prefix", "*") == "*" ? var.instance.spec.domains[rule.domain_key].domain :
        # Rule prefix matches an equivalent_prefix → use bare domain
        contains(
          lookup(var.instance.spec.domains[rule.domain_key], "equivalent_prefixes", []),
          lookup(rule, "domain_prefix", "")
        ) ? var.instance.spec.domains[rule.domain_key].domain :
        # Rule has empty prefix → use bare domain
        lookup(rule, "domain_prefix", "") == "" ? var.instance.spec.domains[rule.domain_key].domain :
        # Normal case → prefix.domain (subdomain)
        "${lookup(rule, "domain_prefix", "*")}.${var.instance.spec.domains[rule.domain_key].domain}"
      )
      rule        = rule
      rule_key    = rule_key
      domain_key  = rule.domain_key
      domain      = var.instance.spec.domains[rule.domain_key].domain
      service     = rule.service
      path        = lookup(rule, "path", "/")
      path_type   = lookup(rule, "path_type", "PREFIX")
      priority    = lookup(rule, "priority", 100)
      certificate = lookup(var.instance.spec.domains[rule.domain_key], "certificate", {})
    }
  }

  # Combined: all rules with computed hosts
  rules_by_host = merge(local.global_rules_by_host, local.domain_specific_rules_by_host)

  # ─── Unique Hosts ───────────────────────────────────────────────────────────
  # All unique hosts that need routing (for URL map host rules)
  unique_hosts = distinct([for key, config in local.rules_by_host : config.host])

  # Group rules by host for URL map path matchers
  rules_grouped_by_host = {
    for host in local.unique_hosts :
    host => [
      for key, config in local.rules_by_host :
      config if config.host == host
    ]
  }

  # ─── Service Extraction ─────────────────────────────────────────────────────
  # Create a map of services for backend creation
  # Key = rule_key (stable), Value = service_name
  services_map = {
    for rule_key, rule in var.instance.spec.rules :
    rule_key => rule.service
    if lookup(rule, "service", "") != ""
  }

  # ─── Certificate Configuration ──────────────────────────────────────────────
  # Determine certificate strategy per host

  # Build host-to-domain mapping for certificate lookup
  host_to_domain = {
    for key, config in local.rules_by_host :
    config.host => {
      domain_key  = config.domain_key
      domain      = config.domain
      certificate = config.certificate
    }...
  }

  # Deduplicated host certificate config (first match wins)
  host_certificate_config = {
    for host in local.unique_hosts :
    host => local.host_to_domain[host][0]
  }

  # Certificates to create (auto or managed mode)
  managed_certs = {
    for host, config in local.host_certificate_config :
    host => {
      cert_name = (
        lookup(config.certificate, "mode", "auto") == "auto"
        ? "${local.name}-${substr(md5(host), 0, 8)}"
        : lookup(config.certificate, "managed_cert_name", "${local.name}-${substr(md5(host), 0, 8)}")
      )
      domain = host
    }
    if contains(["auto", "managed"], lookup(config.certificate, "mode", "auto"))
  }

  # Existing certificates to reference
  existing_certs = {
    for host, config in local.host_certificate_config :
    host => lookup(config.certificate, "existing_cert_name", "")
    if lookup(config.certificate, "mode", "auto") == "existing" && lookup(config.certificate, "existing_cert_name", "") != ""
  }

  # Wildcard certificates (covers all subdomains of a domain)
  wildcard_certs = {
    for host, config in local.host_certificate_config :
    host => lookup(config.certificate, "existing_cert_name", "")
    if lookup(config.certificate, "mode", "auto") == "wildcard" && lookup(config.certificate, "existing_cert_name", "") != ""
  }

  # ─── Global Config ──────────────────────────────────────────────────────────
  global_config  = lookup(var.instance.spec, "global_config", {})
  enable_cdn     = lookup(local.global_config, "enable_cdn", false)
  enable_iap     = lookup(local.global_config, "enable_iap", false)
  timeout_sec    = lookup(local.global_config, "timeout_sec", 30)
  custom_headers = lookup(local.global_config, "custom_headers", {})

  # ─── Advanced Config ────────────────────────────────────────────────────────
  advanced_config             = lookup(var.instance.spec, "advanced", {})
  enable_http                 = lookup(local.advanced_config, "enable_http", true)
  http_redirect               = lookup(local.advanced_config, "http_redirect", true)
  session_affinity            = lookup(local.advanced_config, "session_affinity", "NONE")
  connection_draining_timeout = lookup(local.advanced_config, "connection_draining_timeout", 300)

  # ─── Labels ─────────────────────────────────────────────────────────────────
  labels = merge(
    var.environment.cloud_tags,
    {
      managed_by  = "facets"
      environment = var.environment.name
      instance    = var.instance_name
    }
  )
}
