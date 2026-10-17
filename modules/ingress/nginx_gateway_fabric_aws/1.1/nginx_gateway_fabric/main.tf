# Read control plane metadata from environment variables
data "external" "cc_env" {
  program = ["sh", "-c", <<-EOT
    echo "{\"cc_tenant_provider\":\"$TF_VAR_cc_tenant_provider\",\"tenant_base_domain\":\"$TF_VAR_tenant_base_domain\"}"
  EOT
  ]
}

# Fetch Route53 zone by domain name (AWS only)
data "aws_route53_zone" "base-domain-zone" {
  count    = local.tenant_provider == "aws" ? 1 : 0
  name     = local.tenant_base_domain
  provider = aws3tooling
}

locals {
  # Control plane metadata from environment variables
  cc_tenant_provider    = data.external.cc_env.result.cc_tenant_provider
  tenant_base_domain    = data.external.cc_env.result.tenant_base_domain
  tenant_provider       = lower(local.cc_tenant_provider != "" ? local.cc_tenant_provider : "aws")
  tenant_base_domain_id = length(data.aws_route53_zone.base-domain-zone) > 0 ? data.aws_route53_zone.base-domain-zone[0].zone_id : ""
  cloud_provider        = upper(try(var.inputs.kubernetes_details.cloud_provider, "aws"))

  base_helm_values_raw = lookup(var.instance.spec, "helm_values", {})

  # When user provides nginx.service.patches in helm_values, Helm replaces the
  # entire patches array — losing the module's service annotations patch.
  # Fix: prepend the module's patch into the user-provided array so both survive.
  base_helm_values = can(local.base_helm_values_raw.nginx.service.patches) ? merge(
    local.base_helm_values_raw,
    {
      nginx = merge(
        local.base_helm_values_raw.nginx,
        {
          service = merge(
            local.base_helm_values_raw.nginx.service,
            {
              patches = concat(
                [{
                  type = "StrategicMerge"
                  value = {
                    metadata = {
                      labels      = local.common_labels
                      annotations = var.service_annotations
                    }
                  }
                }],
                local.base_helm_values_raw.nginx.service.patches
              )
            }
          )
        }
      )
    }
  ) : local.base_helm_values_raw

  # Load balancer configuration - determine record type based on what's actually available
  lb_hostname     = try(data.kubernetes_service.gateway_lb.status[0].load_balancer[0].ingress[0].hostname, "")
  lb_ip           = try(data.kubernetes_service.gateway_lb.status[0].load_balancer[0].ingress[0].ip, "")
  record_type     = local.lb_hostname != "" ? "CNAME" : "A"
  lb_record_value = local.lb_hostname != "" ? local.lb_hostname : local.lb_ip

  # Rules configuration
  rulesRaw = lookup(var.instance.spec, "rules", {})

  # Domain configuration (same as nginx_k8s)
  instance_env_name   = length(var.environment.unique_name) + length(var.instance_name) + length(local.tenant_base_domain) >= 60 ? substr(md5("${var.instance_name}-${var.environment.unique_name}"), 0, 20) : "${var.instance_name}-${var.environment.unique_name}"
  check_domain_prefix = coalesce(lookup(var.instance.spec, "domain_prefix_override", null), local.instance_env_name)
  base_domain         = lower("${local.check_domain_prefix}.${local.tenant_base_domain}")
  base_subdomain      = "*.${local.base_domain}"
  name                = lower(var.environment.namespace == "default" ? "${var.instance_name}" : "${var.environment.namespace}-${var.instance_name}")
  gateway_class_name  = local.name

  # Conditionally append base domain
  add_base_domain = lookup(var.instance.spec, "disable_base_domain", false) ? {} : {
    "facets" = {
      "domain" = "${local.base_domain}"
      "alias"  = "base"
    }
  }

  domains = merge(lookup(var.instance.spec, "domains", {}), local.add_base_domain)

  # List of all domain hostnames for HTTPRoutes
  all_domain_hostnames = [for domain_key, domain in local.domains : domain.domain]

  # Filter rules
  rulesFiltered = {
    for k, v in local.rulesRaw : length(k) < 175 ? k : md5(k) => merge(v, {
      # A rule with no domain_prefix is bound to the apex (bare) domain; otherwise
      # to a subdomain. This drives both its hostname and which listener it attaches to.
      is_apex    = lookup(v, "domain_prefix", null) == null || lookup(v, "domain_prefix", null) == ""
      host       = lookup(v, "domain_prefix", null) == null || lookup(v, "domain_prefix", null) == "" ? "${local.base_domain}" : "${lookup(v, "domain_prefix", null)}.${local.base_domain}"
      domain_key = "facets"
      namespace  = lookup(v, "namespace", var.environment.namespace)
    })
    if(
      (lookup(v, "port", null) != null && lookup(v, "port", null) != "") &&
      (lookup(v, "service_name", null) != null && lookup(v, "service_name", "") != "") &&
      (
        # gRPC routes don't need path/path_type - they use method matching
        lookup(lookup(v, "grpc_config", {}), "enabled", false) ||
        # HTTP routes require path (path_type defaults to PathPrefix)
        (lookup(v, "path", null) != null && lookup(v, "path", "") != "")
      ) &&
      (lookup(v, "disable", false) == false)
    )
  }

  # Generate all unique hostnames from rules (domain_prefix + domain combinations)
  # This is needed to create listeners for each hostname
  all_route_hostnames = distinct(flatten([
    for rule_key, rule in local.rulesFiltered : [
      for domain_key, domain in local.domains :
      lookup(rule, "domain_prefix", null) == null || lookup(rule, "domain_prefix", null) == "" ?
      domain.domain :
      "${lookup(rule, "domain_prefix", null)}.${domain.domain}"
    ]
  ]))

  # Hostnames that need additional listeners (not already covered by base domain listeners)
  additional_hostnames = [
    for hostname in local.all_route_hostnames :
    hostname if !contains(local.all_domain_hostnames, hostname)
  ]

  # Domains that have a certificate_reference (wildcard cert covers subdomains)
  domains_with_cert_ref = {
    for domain_key, domain in local.domains :
    domain.domain => lookup(domain, "certificate_reference", "")
    if lookup(domain, "certificate_reference", "") != ""
  }

  # Map of additional hostnames to their config for listeners and certs
  # Subdomains of domains with certificate_reference are excluded — the wildcard listener covers them
  # When external TLS is enabled, all per-domain listeners use wildcard hostnames, so no additional listeners needed
  additional_hostname_configs = var.external_tls_termination ? {} : {
    for hostname in local.additional_hostnames :
    replace(replace(hostname, ".", "-"), "*", "wildcard") => {
      hostname    = hostname
      secret_name = "${local.name}-${replace(replace(hostname, ".", "-"), "*", "wildcard")}-tls-cert"
    }
    # Exclude subdomains of domains with certificate_reference (covered by wildcard listener)
    if !anytrue([for parent_domain, cert_ref in local.domains_with_cert_ref : endswith(hostname, ".${parent_domain}")])
  }

  # Per-domain HTTPS listeners for the Gateway (cert-manager mode; flat data only,
  # rendered into listener objects in the Gateway resource below).
  #
  # A domain with a certificate_reference (DNS-01 / external cert) has a cert whose
  # SANs cover BOTH the apex and the wildcard (dnsNames = [domain, *.domain]), so it
  # gets TWO listeners: a wildcard listener (https-<key>) for subdomains and an apex
  # listener (https-<key>-apex) for the bare domain. Without the apex listener, rules
  # with no domain_prefix have no listener to attach to. A plain cert-manager domain
  # (no cert_ref) keeps a single apex listener whose cert this module issues.
  https_domain_listeners = flatten([
    for domain_key, domain in local.domains : (
      lookup(domain, "certificate_reference", "") != "" ? [
        { name = "https-${domain_key}", hostname = "*.${domain.domain}", secret = domain.certificate_reference },
        { name = "https-${domain_key}-apex", hostname = domain.domain, secret = domain.certificate_reference },
        ] : [
        { name = "https-${domain_key}", hostname = domain.domain, secret = "${local.name}-${domain_key}-tls-cert" },
      ]
    ) if can(domain.domain)
  ])

  # Nodepool configuration
  nodepool_config_raw = lookup(var.inputs, "kubernetes_node_pool_details", null)
  nodepool_config_json = local.nodepool_config_raw != null ? (
    lookup(local.nodepool_config_raw, "attributes", null) != null ?
    jsonencode(local.nodepool_config_raw.attributes) :
    jsonencode(local.nodepool_config_raw)
    ) : jsonencode({
      node_class_name = ""
      node_pool_name  = ""
      taints          = []
      node_selector   = {}
  })
  nodepool_config      = jsondecode(local.nodepool_config_json)
  nodepool_tolerations = lookup(local.nodepool_config, "taints", [])
  nodepool_labels      = lookup(local.nodepool_config, "node_selector", {})

  ingress_tolerations = local.nodepool_tolerations

  gateway_api_crd_labels = {
    "facets.cloud/gateway-api-crd"         = "true",
    "facets.cloud/gateway-api-crd-job"     = var.inputs.gateway_api_crd_details.attributes.job_name
    "facets.cloud/gateway-api-crd-version" = var.inputs.gateway_api_crd_details.attributes.version
  }

  # Common labels for all resources
  common_labels = merge({
    "app.kubernetes.io/managed-by" = "facets"
    "facets.cloud/module"          = "nginx_gateway_fabric"
    "facets.cloud/instance"        = var.instance_name
    },
    local.gateway_api_crd_labels
  )

  # Domains that need bootstrap TLS certificates for HTTP-01 validation
  # Bootstrap cert is needed for domains without certificate_reference
  # Not needed when TLS is terminated externally (e.g., at the NLB)
  bootstrap_tls_domains = var.external_tls_termination ? {} : {
    for domain_key, domain in local.domains :
    domain_key => domain
    if can(domain.domain) && lookup(domain, "certificate_reference", "") == ""
  }

  # Domains that need cert-manager to issue certificates
  # Only domains WITHOUT certificate_reference
  # Not needed when TLS is terminated externally
  certmanager_managed_domains = var.external_tls_termination ? {} : {
    for domain_key, domain in local.domains :
    domain_key => domain
    if can(domain.domain) && lookup(domain, "certificate_reference", "") == ""
  }

  # Use gateway-shim only when ALL domains are managed by cert-manager
  # When false (some domains have certificate_reference), we create explicit Certificate resources
  # Never use gateway-shim when TLS is terminated externally
  use_gateway_shim = !var.external_tls_termination && length(local.certmanager_managed_domains) == length(local.domains)

  # Get ClusterIssuer names and config from cert-manager
  cluster_issuer_gateway_http = "${local.name}-gateway-http01"
  acme_email                  = lookup(var.inputs, "cert_manager_details", null) != null ? lookup(var.inputs.cert_manager_details.attributes, "acme_email", "systems@facets.cloud") : "systems@facets.cloud"

  # Allow override of ClusterIssuer - useful for staging, custom issuers, or rate limit bypass
  cluster_issuer_override  = lookup(var.instance.spec, "cluster_issuer_override", null)
  effective_cluster_issuer = coalesce(local.cluster_issuer_override, local.cluster_issuer_gateway_http)

  # CORS headers per route
  cors_headers = {
    for k, v in local.rulesFiltered : k => merge(
      lookup(lookup(v, "cors", {}), "enabled", false) ? {
        "Access-Control-Allow-Origin" = join(", ", length(lookup(lookup(v, "cors", {}), "allow_origins", {})) > 0 ?
          [for key, origin in lookup(lookup(v, "cors", {}), "allow_origins", {}) : origin.origin] :
          ["*"]
        )
        "Access-Control-Allow-Methods" = join(", ", length(lookup(lookup(v, "cors", {}), "allow_methods", {})) > 0 ?
          [for key, m in lookup(lookup(v, "cors", {}), "allow_methods", {}) : m.method] :
          ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
        )
        "Access-Control-Allow-Headers" = join(", ", length(lookup(lookup(v, "cors", {}), "allow_headers", {})) > 0 ?
          [for key, h in lookup(lookup(v, "cors", {}), "allow_headers", {}) : h.header] :
          ["Content-Type", "Authorization"]
        )
        "Access-Control-Max-Age" = tostring(lookup(lookup(v, "cors", {}), "max_age", 86400))
      } : {},
      lookup(lookup(v, "cors", {}), "allow_credentials", false) ? {
        "Access-Control-Allow-Credentials" = "true"
      } : {}
    )
  }

  # HTTP to HTTPS Redirect Route (only created when force_ssl_redirection is enabled)
  # Single route that handles ALL HTTP (port 80) traffic and redirects to HTTPS
  # MUST NOT have backendRefs - only RequestRedirect filter
  http_redirect_resources = lookup(var.instance.spec, "force_ssl_redirection", false) ? {
    "httproute-redirect-${local.name}" = {
      apiVersion = "gateway.networking.k8s.io/v1"
      kind       = "HTTPRoute"
      metadata = {
        name      = "${local.name}-http-redirect"
        namespace = var.environment.namespace
      }
      spec = {
        parentRefs = [{
          name        = local.name
          namespace   = var.environment.namespace
          sectionName = "http" # Reference HTTP listener (port 80)
        }]

        rules = [{
          matches = [{
            path = {
              type  = "PathPrefix"
              value = "/"
            }
          }]
          filters = [{
            type = "RequestRedirect"
            requestRedirect = {
              scheme     = "https"
              statusCode = 301
            }
          }]
          # No backendRefs - redirect only
        }]
      }
    }
  } : {}

  # HTTPRoute Resources (HTTPS traffic - port 443, and HTTP - port 80 when force_ssl_redirection is disabled)
  # Note: GatewayClass, Gateway, and NginxProxy are created by the Helm chart
  force_ssl_redirection = lookup(var.instance.spec, "force_ssl_redirection", false)

  # When external TLS termination is active, routes need split variants (one per listener)
  # so that X-Forwarded-Proto can be set correctly per protocol via RequestHeaderModifier.
  # - "https" variant: attached to HTTPS listener, sets proto headers to "https"
  # - "http" variant: attached to HTTP listener, sets proto headers to "http"
  #   (NGF only sets X-Forwarded-Proto by default, not X-Forwarded-Scheme/X-Scheme,
  #    so we must explicitly set all three on both variants for parity)
  # When external_tls_termination is false, $scheme is accurate and no split/filter is needed.
  httproute_variants = var.external_tls_termination && !local.force_ssl_redirection ? {
    "https" = { suffix = "-https", listener = "https", proto = "https" }
    "http"  = { suffix = "-http", listener = "http", proto = "http" }
    } : (var.external_tls_termination ? {
      "https" = { suffix = "", listener = "https", proto = "https" }
      } : {
      "default" = { suffix = "", listener = "default", proto = null }
  })

  httproute_resources = merge([
    for variant_key, variant in local.httproute_variants : {
      for k, v in local.rulesFiltered : "httproute-${lower(var.instance_name)}-${k}${variant.suffix}" => {
        apiVersion = "gateway.networking.k8s.io/v1"
        kind       = "HTTPRoute"
        metadata = {
          name      = "${lower(var.instance_name)}-${k}${variant.suffix}"
          namespace = var.environment.namespace
        }
        spec = {
          # Reference the correct listener(s) for this route's hostnames
          # External TLS mode: split routes reference individual listeners (https or http)
          # cert-manager mode: routes reference per-domain HTTPS listeners + optionally HTTP
          parentRefs = variant.listener == "https" ? [{
            name        = local.name
            namespace   = var.environment.namespace
            sectionName = "https"
            }] : (variant.listener == "http" ? [{
              name        = local.name
              namespace   = var.environment.namespace
              sectionName = "http"
            }] : (
            # Default (non-external-TLS): original logic with both listeners
            concat(
              # One HTTPS parentRef per domain. An apex rule (no domain_prefix) attaches to
              # the domain's apex listener; a subdomain rule attaches to the wildcard
              # listener (cert_ref domains) or its per-hostname listener (cert-manager).
              [
                for domain_key, domain in local.domains : {
                  name      = local.name
                  namespace = var.environment.namespace
                  sectionName = lookup(domain, "certificate_reference", "") != "" ? (
                    v.is_apex ? "https-${domain_key}-apex" : "https-${domain_key}"
                    ) : (
                    v.is_apex ? "https-${domain_key}" : "https-${replace(replace("${lookup(v, "domain_prefix", null)}.${domain.domain}", ".", "-"), "*", "wildcard")}"
                  )
                }
              ],
              !local.force_ssl_redirection ? [{
                name        = local.name
                namespace   = var.environment.namespace
                sectionName = "http"
              }] : []
            )
          ))

          # Include all domains in hostnames - Gateway API supports multiple hostnames per route
          hostnames = distinct([
            for domain_key, domain in local.domains :
            lookup(v, "domain_prefix", null) == null || lookup(v, "domain_prefix", null) == "" ?
            domain.domain :
            "${lookup(v, "domain_prefix", null)}.${domain.domain}"
          ])

          rules = [{
            matches = concat(
              # Path matching (with optional method and query params)
              [merge(
                {
                  path = {
                    type  = lookup(v, "path_type", "RegularExpression")
                    value = lookup(v, "path", "/")
                  }
                },
                # Method matching (ALL or null means match all methods)
                lookup(v, "method", null) != null && lookup(v, "method", "ALL") != "ALL" ? {
                  method = v.method
                } : {},
                # Query parameter matching
                length(lookup(v, "query_param_matches", {})) > 0 ? {
                  queryParams = [
                    for key, qp in v.query_param_matches : {
                      name  = qp.name
                      value = qp.value
                      type  = lookup(qp, "type", "Exact")
                    }
                  ]
                } : {},
                # Header matching
                length(lookup(v, "header_matches", {})) > 0 ? {
                  headers = [
                    for key, header in v.header_matches : {
                      name  = header.name
                      value = header.value
                      type  = lookup(header, "type", "Exact")
                    }
                  ]
                } : {}
              )]
            )

            filters = concat(
              # Basic auth filter (applied when basic_auth is enabled and route doesn't have disable_auth)
              lookup(var.instance.spec, "basic_auth", false) && !lookup(v, "disable_auth", false) ? [{
                type = "ExtensionRef"
                extensionRef = {
                  group = "gateway.nginx.org"
                  kind  = "AuthenticationFilter"
                  name  = "${local.name}-basic-auth"
                }
              }] : [],
              # Static filters
              [
                for filter in [
                  # Request header modification (merges user-specified headers with external TLS proto headers)
                  # Gateway API allows only one RequestHeaderModifier per rule, so we merge them
                  # Request header modification (merges user-specified headers with external TLS proto headers)
                  # Gateway API allows only one RequestHeaderModifier per rule, so we merge them.
                  # User-specified headers take precedence — if the user sets X-Forwarded-Proto etc.
                  # in their spec, we don't inject our version for those headers.
                  (lookup(v, "request_header_modifier", null) != null || variant.proto != null) ? {
                    type = "RequestHeaderModifier"
                    requestHeaderModifier = merge(
                      lookup(lookup(v, "request_header_modifier", {}), "add", null) != null ? {
                        add = [for key, header in v.request_header_modifier.add : { name = header.name, value = header.value }]
                      } : {},
                      {
                        set = concat(
                          try([for key, header in v.request_header_modifier.set : { name = header.name, value = header.value }], []),
                          # Only inject proto headers that the user hasn't already specified
                          variant.proto != null ? [
                            for h in [
                              { name = "X-Forwarded-Proto", value = variant.proto },
                              { name = "X-Forwarded-Scheme", value = variant.proto },
                              { name = "X-Scheme", value = variant.proto },
                              ] : h if !contains(
                              try([for key, header in v.request_header_modifier.set : lower(header.name)], []),
                              lower(h.name)
                            )
                          ] : []
                        )
                      },
                      lookup(lookup(v, "request_header_modifier", {}), "remove", null) != null ? {
                        remove = [for key, header in v.request_header_modifier.remove : header.name]
                      } : {}
                    )
                  } : null,

                  # Response header modification (security headers + CORS + custom headers)
                  {
                    type = "ResponseHeaderModifier"
                    responseHeaderModifier = merge(
                      {
                        add = [for name, value in merge(
                          { for key, header in lookup(lookup(v, "response_header_modifier", {}), "add", {}) : header.name => header.value },
                          local.cors_headers[k]
                        ) : { name = name, value = value }]
                      },
                      lookup(lookup(v, "response_header_modifier", {}), "set", null) != null ? {
                        set = [for key, header in v.response_header_modifier.set : { name = header.name, value = header.value }]
                      } : {},
                      lookup(lookup(v, "response_header_modifier", {}), "remove", null) != null ? {
                        remove = [for key, header in v.response_header_modifier.remove : header.name]
                      } : {}
                    )
                  },

                  # Request mirroring
                  lookup(v, "request_mirror", null) != null ? {
                    type = "RequestMirror"
                    requestMirror = {
                      backendRef = {
                        name      = v.request_mirror.service_name
                        port      = tonumber(v.request_mirror.port)
                        namespace = lookup(v.request_mirror, "namespace", v.namespace)
                      }
                    }
                  } : null
                  # Note: SSL redirection is handled by separate http_redirect_resources HTTPRoutes
                  # RequestRedirect filter cannot be used together with backendRefs in the same rule
                ] : filter if filter != null
              ],
              # URL rewriting (from patternProperties)
              [
                for key, rewrite in lookup(v, "url_rewrite", {}) : {
                  type = "URLRewrite"
                  urlRewrite = merge(
                    lookup(rewrite, "hostname", null) != null ? {
                      hostname = rewrite.hostname
                    } : {},
                    lookup(rewrite, "path_type", null) != null && lookup(rewrite, "replace_path", null) != null ? {
                      path = merge(
                        { type = rewrite.path_type },
                        rewrite.path_type == "ReplaceFullPath" ? {
                          replaceFullPath = rewrite.replace_path
                        } : {},
                        rewrite.path_type == "ReplacePrefixMatch" ? {
                          replacePrefixMatch = rewrite.replace_path
                        } : {}
                      )
                    } : {}
                  )
                }
              ],
              # Per-rule SnippetsFilter ExtensionRef (nginx_timeouts) — ported from
              # nginx_gateway_fabric_capillary. Applies proxy_*_timeout at http.server.location,
              # overriding the gateway-wide proxy-timeouts default for this route.
              contains(keys(local.rules_needing_snippetsfilter), k) ? [{
                type = "ExtensionRef"
                extensionRef = {
                  group = "gateway.nginx.org"
                  kind  = "SnippetsFilter"
                  name  = local.rule_snippet_names[k]
                }
              }] : []
            )

            # NOTE: Gateway-API HTTPRoute rules[].timeouts is still omitted — NGF 2.4.1
            # ignores it (#2164). Per-rule proxy_*_timeout is delivered via nginx_timeouts
            # (SnippetsFilter ExtensionRef above); gateway-wide default via proxy-timeouts SnippetsPolicy.
            backendRefs = concat(
              # Primary backend
              [{
                name      = v.service_name
                port      = tonumber(v.port)
                weight    = lookup(lookup(v, "canary_deployment", {}), "enabled", false) ? 100 - lookup(lookup(v, "canary_deployment", {}), "canary_weight", 10) : 100
                namespace = v.namespace
              }],
              # Canary backend (if enabled)
              lookup(lookup(v, "canary_deployment", {}), "enabled", false) ? [{
                name      = lookup(lookup(v, "canary_deployment", {}), "canary_service", "")
                port      = tonumber(v.port)
                weight    = lookup(lookup(v, "canary_deployment", {}), "canary_weight", 10)
                namespace = v.namespace
              }] : []
            )
          }]
        }
      } if !lookup(lookup(v, "grpc_config", {}), "enabled", false)
    }
  ]...)

  # GRPCRoute Resources — same split-variant logic as HTTPRoutes for external TLS termination
  grpcroute_variants = var.external_tls_termination && !local.force_ssl_redirection ? {
    "https" = { suffix = "-https", listener = "https", proto = "https" }
    "http"  = { suffix = "-http", listener = "http", proto = "http" }
    } : (var.external_tls_termination ? {
      "https" = { suffix = "", listener = "https", proto = "https" }
      } : {
      "default" = { suffix = "", listener = "default", proto = null }
  })

  grpcroute_resources = merge([
    for variant_key, variant in local.grpcroute_variants : {
      for k, v in local.rulesFiltered : "grpcroute-${lower(var.instance_name)}-${k}${variant.suffix}" => {
        apiVersion = "gateway.networking.k8s.io/v1"
        kind       = "GRPCRoute"
        metadata = {
          name      = "${lower(var.instance_name)}-${k}-grpc${variant.suffix}"
          namespace = var.environment.namespace
        }
        spec = {
          parentRefs = variant.listener == "https" ? [{
            name        = local.name
            namespace   = var.environment.namespace
            sectionName = "https"
            }] : (variant.listener == "http" ? [{
              name        = local.name
              namespace   = var.environment.namespace
              sectionName = "http"
            }] : (
            concat(
              # One HTTPS parentRef per domain. An apex rule (no domain_prefix) attaches to
              # the domain's apex listener; a subdomain rule attaches to the wildcard
              # listener (cert_ref domains) or its per-hostname listener (cert-manager).
              [
                for domain_key, domain in local.domains : {
                  name      = local.name
                  namespace = var.environment.namespace
                  sectionName = lookup(domain, "certificate_reference", "") != "" ? (
                    v.is_apex ? "https-${domain_key}-apex" : "https-${domain_key}"
                    ) : (
                    v.is_apex ? "https-${domain_key}" : "https-${replace(replace("${lookup(v, "domain_prefix", null)}.${domain.domain}", ".", "-"), "*", "wildcard")}"
                  )
                }
              ],
              !local.force_ssl_redirection ? [{
                name        = local.name
                namespace   = var.environment.namespace
                sectionName = "http"
              }] : []
            )
          ))

          hostnames = distinct([
            for domain_key, domain in local.domains :
            lookup(v, "domain_prefix", null) == null || lookup(v, "domain_prefix", null) == "" ?
            domain.domain :
            "${lookup(v, "domain_prefix", null)}.${domain.domain}"
          ])

          rules = [{
            matches = !lookup(lookup(v, "grpc_config", {}), "match_all_methods", true) && lookup(lookup(v, "grpc_config", {}), "method_match", null) != null ? [
              for key, method in lookup(v.grpc_config, "method_match", {}) : {
                method = {
                  type    = lookup(method, "type", "Exact")
                  service = lookup(method, "service", "")
                  method  = lookup(method, "method", "")
                }
              }
            ] : []

            filters = concat(
              lookup(var.instance.spec, "basic_auth", false) && !lookup(v, "disable_auth", false) ? [{
                type = "ExtensionRef"
                extensionRef = {
                  group = "gateway.nginx.org"
                  kind  = "AuthenticationFilter"
                  name  = "${local.name}-basic-auth"
                }
              }] : [],
              # External TLS proto headers via RequestHeaderModifier (GRPCRoute supports this in Gateway API v1)
              # User-specified headers take precedence — same dedup logic as HTTPRoutes
              variant.proto != null ? [{
                type = "RequestHeaderModifier"
                requestHeaderModifier = {
                  set = [
                    for h in [
                      { name = "X-Forwarded-Proto", value = variant.proto },
                      { name = "X-Forwarded-Scheme", value = variant.proto },
                      { name = "X-Scheme", value = variant.proto },
                      ] : h if !contains(
                      try([for key, header in lookup(lookup(v, "request_header_modifier", {}), "set", {}) : lower(header.name)], []),
                      lower(h.name)
                    )
                  ]
                }
              }] : [],
              # Per-rule SnippetsFilter ExtensionRef (nginx_timeouts) — gRPC routes
              contains(keys(local.rules_needing_snippetsfilter), k) ? [{
                type = "ExtensionRef"
                extensionRef = {
                  group = "gateway.nginx.org"
                  kind  = "SnippetsFilter"
                  name  = local.rule_snippet_names[k]
                }
              }] : []
            )

            backendRefs = [{
              name      = v.service_name
              port      = tonumber(v.port)
              namespace = v.namespace
            }]
          }]
        }
      } if lookup(lookup(v, "grpc_config", {}), "enabled", false)
    }
  ]...)

  # PodMonitor (only created when prometheus_details input is provided)
  # Scrapes both control plane and data plane pods using common instance label
  podmonitor_resources = lookup(var.inputs, "prometheus_details", null) != null ? {
    "podmonitor-${local.name}" = {
      apiVersion = "monitoring.coreos.com/v1"
      kind       = "PodMonitor"
      metadata = {
        name      = "${local.name}-metrics"
        namespace = var.environment.namespace
        labels = {
          # Label required by Prometheus Operator to discover this PodMonitor
          release = try(var.inputs.prometheus_details.attributes.helm_release_id, "prometheus")
        }
      }
      spec = {
        selector = {
          matchLabels = {
            # Common label shared by both control plane and data plane pods
            "app.kubernetes.io/instance" = local.helm_release_name
          }
        }
        podMetricsEndpoints = [{
          port     = "metrics"
          interval = "30s"
          path     = "/metrics"
        }]
      }
    }
  } : {}

  # Collect unique namespaces that need ReferenceGrants (for cross-namespace backends)
  # Fix: use distinct() to avoid duplicate key error when multiple rules share the same namespace
  cross_namespace_backends = {
    for ns in distinct([for k, v in local.rulesFiltered : v.namespace if v.namespace != var.environment.namespace]) : ns => ns
  }

  # ReferenceGrant resources for cross-namespace backends
  # Allows HTTPRoutes and GRPCRoutes in Gateway namespace to reference Services in other namespaces
  referencegrant_resources = {
    for ns in local.cross_namespace_backends : "referencegrant-${ns}" => {
      apiVersion = "gateway.networking.k8s.io/v1beta1"
      kind       = "ReferenceGrant"
      metadata = {
        name      = "${local.name}-allow-routes"
        namespace = ns
      }
      spec = {
        from = [
          {
            group     = "gateway.networking.k8s.io"
            kind      = "HTTPRoute"
            namespace = var.environment.namespace
          },
          {
            group     = "gateway.networking.k8s.io"
            kind      = "GRPCRoute"
            namespace = var.environment.namespace
          }
        ]
        to = [{
          group = ""
          kind  = "Service"
        }]
      }
    }
  }

  # ClientSettingsPolicy - applies body size limit to all traffic through the Gateway
  # Equivalent to nginx.ingress.kubernetes.io/proxy-body-size
  clientsettingspolicy_resources = {
    "clientsettingspolicy-${local.name}" = {
      apiVersion = "gateway.nginx.org/v1alpha1"
      kind       = "ClientSettingsPolicy"
      metadata = {
        name      = "${local.name}-client-settings"
        namespace = var.environment.namespace
      }
      spec = {
        targetRef = {
          group = "gateway.networking.k8s.io"
          kind  = "Gateway"
          name  = local.name
        }
        body = {
          maxSize = lookup(var.instance.spec, "body_size", "150m")
        }
      }
    }
  }

  # AuthenticationFilter for basic auth (NGF native CRD)
  authenticationfilter_resources = lookup(var.instance.spec, "basic_auth", false) ? {
    "authfilter-${local.name}" = {
      apiVersion = "gateway.nginx.org/v1alpha1"
      kind       = "AuthenticationFilter"
      metadata = {
        name      = "${local.name}-basic-auth"
        namespace = var.environment.namespace
      }
      spec = {
        type = "Basic"
        basic = {
          realm = "Authentication required"
          secretRef = {
            name = "${local.name}-basic-auth"
          }
        }
      }
    }
  } : {}

  # Resolved instance-level proxy timeouts. Default 300s for parity with the legacy
  # nginx_ingress_controller being migrated off (its proxy-{connect,read,send}-timeout
  # defaults were 300s); workloads with long-running requests would otherwise be cut off
  # at nginx's built-in 60s. Override per-ingress via spec. Applied gateway-wide via the
  # proxy-timeouts SnippetsPolicy (http.server); per-rule nginx_timeouts (SnippetsFilter,
  # http.server.location) overrides per route.
  instance_proxy_connect_timeout = lookup(var.instance.spec, "proxy_connect_timeout", "300s")
  instance_proxy_read_timeout    = lookup(var.instance.spec, "proxy_read_timeout", "300s")
  instance_proxy_send_timeout    = lookup(var.instance.spec, "proxy_send_timeout", "300s")

  # SnippetsPolicy resources:
  # - request-id: X-Request-ID / FACETS-REQUEST-ID injection (external TLS termination only)
  # - proxy-timeouts (instance-level): proxy_{connect,read,send}_timeout at http.server scope, applies to all routes
  snippetspolicy_resources = merge(
    var.external_tls_termination ? {
      "snippetspolicy-${local.name}-request-id" = {
        apiVersion = "gateway.nginx.org/v1alpha1"
        kind       = "SnippetsPolicy"
        metadata = {
          name      = "${local.name}-request-id"
          namespace = var.environment.namespace
        }
        spec = {
          targetRefs = [{
            group = "gateway.networking.k8s.io"
            kind  = "Gateway"
            name  = local.name
          }]
          snippets = [
            {
              context = "http.server.location"
              value   = "proxy_set_header X-Request-ID $request_id;\nproxy_set_header FACETS-REQUEST-ID $request_id;"
            }
          ]
        }
      }
    } : {},
    {
      "snippetspolicy-${local.name}-proxy-timeouts" = {
        apiVersion = "gateway.nginx.org/v1alpha1"
        kind       = "SnippetsPolicy"
        metadata = {
          name      = "${local.name}-proxy-timeouts"
          namespace = var.environment.namespace
        }
        spec = {
          targetRefs = [{
            group = "gateway.networking.k8s.io"
            kind  = "Gateway"
            name  = local.name
          }]
          snippets = [
            {
              context = "http.server"
              value = join("\n", [
                "proxy_connect_timeout ${local.instance_proxy_connect_timeout};",
                "proxy_read_timeout ${local.instance_proxy_read_timeout};",
                "proxy_send_timeout ${local.instance_proxy_send_timeout};",
              ])
            }
          ]
        }
      }
    },
  )

  # Per-rule SnippetsFilter names — referenced by both the SnippetsFilter resource and
  # the HTTPRoute/GRPCRoute ExtensionRef so the names always match.
  rule_snippet_names = {
    for k, v in local.rulesFiltered :
    k => "${local.name}-${lower(replace(replace(replace(k, "_", "-"), ".", "-"), "/", "-"))}-snippets"
  }

  # Rules that need a per-rule SnippetsFilter (per-rule nginx_timeouts overrides).
  rules_needing_snippetsfilter = {
    for k, v in local.rulesFiltered : k => true
    if lookup(v, "nginx_timeouts", null) != null
  }

  # SnippetsFilter resources — per-rule proxy_{connect,read,send}_timeout rendered at
  # http.server.location, overriding the gateway-wide default for that route. Ported from
  # nginx_gateway_fabric_capillary; wired onto each route via ExtensionRef (HTTP + gRPC).
  snippetsfilter_resources = {
    for k, v in local.rulesFiltered :
    "snippetsfilter-${k}" => {
      apiVersion = "gateway.nginx.org/v1alpha1"
      kind       = "SnippetsFilter"
      metadata = {
        name      = local.rule_snippet_names[k]
        namespace = var.environment.namespace
      }
      spec = {
        snippets = [{
          context = "http.server.location"
          value = join("\n", compact([
            lookup(lookup(v, "nginx_timeouts", {}), "proxy_connect_timeout", null) != null ?
            "proxy_connect_timeout ${v.nginx_timeouts.proxy_connect_timeout};" : null,
            lookup(lookup(v, "nginx_timeouts", {}), "proxy_read_timeout", null) != null ?
            "proxy_read_timeout ${v.nginx_timeouts.proxy_read_timeout};" : null,
            lookup(lookup(v, "nginx_timeouts", {}), "proxy_send_timeout", null) != null ?
            "proxy_send_timeout ${v.nginx_timeouts.proxy_send_timeout};" : null,
          ]))
        }]
      }
    }
    if lookup(v, "nginx_timeouts", null) != null
  }

  # ClusterIssuer for ACME HTTP-01 challenges via Gateway API
  # See: https://github.com/cert-manager/cert-manager/issues/7890
  clusterissuer_resources = length(local.certmanager_managed_domains) > 0 && local.cluster_issuer_override == null ? {
    "clusterissuer-${local.cluster_issuer_gateway_http}" = {
      apiVersion = "cert-manager.io/v1"
      kind       = "ClusterIssuer"
      metadata = {
        name = local.cluster_issuer_gateway_http
      }
      spec = {
        acme = {
          email  = local.acme_email
          server = "https://acme-v02.api.letsencrypt.org/directory"
          privateKeySecretRef = {
            name = "${local.cluster_issuer_gateway_http}-account-key"
          }
          solvers = [
            {
              http01 = {
                gatewayHTTPRoute = {
                  parentRefs = [
                    {
                      name        = local.name
                      namespace   = var.environment.namespace
                      kind        = "Gateway"
                      sectionName = "http"
                    }
                  ]
                }
              }
            },
          ]
        }
      }
    }
  } : {}

  # Certificate resources for HTTP-01 managed base domains
  # Created when NOT using gateway-shim (i.e., when some domains have certificate_reference)
  certificate_resources = !local.use_gateway_shim ? {
    for domain_key, domain in local.certmanager_managed_domains :
    "certificate-${local.name}-${domain_key}" => {
      apiVersion = "cert-manager.io/v1"
      kind       = "Certificate"
      metadata = {
        name      = "${local.name}-http01-cert-${domain_key}"
        namespace = var.environment.namespace
      }
      spec = {
        secretName = "${local.name}-${domain_key}-tls-cert"
        issuerRef = {
          name = local.effective_cluster_issuer
          kind = "ClusterIssuer"
        }
        dnsNames = [
          domain.domain
        ]
        renewBefore = lookup(var.instance.spec, "renew_cert_before", "720h")
      }
    }
  } : {}

  # Certificate resources for additional hostnames (domain_prefix + domain)
  # Only for additional hostnames that don't inherit a parent cert
  certificate_additional_resources = !local.use_gateway_shim ? {
    for key, config in local.additional_hostname_configs :
    "cert-additional-${local.name}-${key}" => {
      apiVersion = "cert-manager.io/v1"
      kind       = "Certificate"
      metadata = {
        name      = "${local.name}-cert-${key}"
        namespace = var.environment.namespace
      }
      spec = {
        secretName = config.secret_name
        issuerRef = {
          name = local.effective_cluster_issuer
          kind = "ClusterIssuer"
        }
        dnsNames = [
          config.hostname
        ]
        renewBefore = lookup(var.instance.spec, "renew_cert_before", "720h")
      }
    }
  } : {}

  # --- Three Helm release groups ---
  # Routes are split into separate releases for ordered deployment and clear separation
  # of HTTPS vs HTTP traffic handling.

  # Release 1: Base infrastructure — everything except HTTPRoutes
  # Includes: policies, monitors, grants, auth filters, snippets, gRPC routes, ClusterIssuer, Certificates
  gateway_api_resources_base = merge(
    local.podmonitor_resources,
    local.referencegrant_resources,
    local.clientsettingspolicy_resources,
    local.authenticationfilter_resources,
    local.snippetspolicy_resources,
    local.snippetsfilter_resources,
    local.grpcroute_resources,
    local.clusterissuer_resources,
    local.certificate_resources,
    local.certificate_additional_resources,
    var.additional_base_resources
  )

  # Release 2: HTTPS HTTPRoutes — routes attached to HTTPS listener(s)
  # When external_tls_termination + split: only routes with "-https" suffix (or no suffix)
  # When non-external-TLS: all routes (they carry both listeners in parentRefs)
  gateway_api_resources_https_routes = merge(
    { for k, v in local.httproute_resources : k => v if !endswith(k, "-http") }
  )

  # Release 3: HTTP traffic handling
  # When force_ssl_redirection = true: single blanket redirect rule (301 HTTP → HTTPS)
  # When force_ssl_redirection = false: HTTP listener HTTPRoutes (the "-http" suffix routes)
  # Uses merge() of both branches to avoid ternary type mismatch between object and map types
  gateway_api_resources_http_routes = merge(
    local.force_ssl_redirection ? local.http_redirect_resources : {},
    local.force_ssl_redirection ? {} : { for k, v in local.httproute_resources : k => v if endswith(k, "-http") }
  )
}

# Bootstrap TLS Private Key for HTTP-01 validation
# Creates a temporary self-signed cert so Gateway 443 listener can start
# cert-manager will overwrite this secret once HTTP-01 challenge succeeds
resource "tls_private_key" "bootstrap" {
  for_each  = local.bootstrap_tls_domains
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "bootstrap" {
  for_each        = local.bootstrap_tls_domains
  private_key_pem = tls_private_key.bootstrap[each.key].private_key_pem

  subject {
    common_name = each.value.domain
  }

  validity_period_hours = 8760 # 1 year

  dns_names = [
    each.value.domain,
    "*.${each.value.domain}"
  ]

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

resource "kubernetes_secret_v1" "bootstrap_tls" {
  for_each = local.bootstrap_tls_domains

  metadata {
    name      = "${local.name}-${each.key}-tls-cert"
    namespace = var.environment.namespace
  }

  data = {
    "tls.crt" = tls_self_signed_cert.bootstrap[each.key].cert_pem
    "tls.key" = tls_private_key.bootstrap[each.key].private_key_pem
  }

  type = "kubernetes.io/tls"

  lifecycle {
    ignore_changes = [data, metadata[0].annotations, metadata[0].labels]
  }
}

# Bootstrap TLS for additional hostnames (from domain_prefix in rules)
# Only for additional hostnames that did NOT inherit a certificate_reference from parent domain
resource "tls_private_key" "bootstrap_additional" {
  for_each  = local.additional_hostname_configs
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "bootstrap_additional" {
  for_each        = local.additional_hostname_configs
  private_key_pem = tls_private_key.bootstrap_additional[each.key].private_key_pem

  subject {
    common_name = each.value.hostname
  }

  validity_period_hours = 8760 # 1 year

  dns_names = [each.value.hostname]

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]
}

resource "kubernetes_secret_v1" "bootstrap_tls_additional" {
  for_each = local.additional_hostname_configs

  metadata {
    name      = each.value.secret_name
    namespace = var.environment.namespace
  }

  data = {
    "tls.crt" = tls_self_signed_cert.bootstrap_additional[each.key].cert_pem
    "tls.key" = tls_private_key.bootstrap_additional[each.key].private_key_pem
  }

  type = "kubernetes.io/tls"

  lifecycle {
    ignore_changes = [data, metadata[0].annotations, metadata[0].labels]
  }
}


# Helm release name - keep under 34 chars so that fullname (release + "-" + chart name = 34+1+20 = 55)
# plus the longest suffix (-certgen, 8 chars) stays within the 63-char k8s label value limit.
#
# spec.helm_release_name_override is honored only when it normalizes to a valid Helm release name:
#   - trimmed of leading/trailing whitespace
#   - non-empty after trimming (null, missing, or whitespace-only treated as absent)
#   - ≤ 34 characters (preserves the 63-char label budget described above)
#   - DNS-1123 label: lowercase alphanumeric and hyphens, starting/ending with alphanumeric
# Anything else silently falls back to the legacy truncated-name default. Form-level validation
# in each parent's facets.yaml rejects bad input at the UI layer; this is defense-in-depth.
locals {
  helm_release_name_override_raw = try(trimspace(tostring(var.instance.spec.helm_release_name_override)), "")
  helm_release_name_override_valid = (
    local.helm_release_name_override_raw != "" &&
    length(local.helm_release_name_override_raw) <= 34 &&
    can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", local.helm_release_name_override_raw))
  ) ? local.helm_release_name_override_raw : ""
  helm_release_name = local.helm_release_name_override_valid != "" ? local.helm_release_name_override_valid : substr(local.name, 0, min(length(local.name), 34))
}

# NGINX Gateway Fabric Helm Chart
# Note: Gateway API CRDs are installed by the gateway_api_crd module (dependency)
resource "helm_release" "nginx_gateway_fabric" {
  name             = local.helm_release_name
  wait             = lookup(var.instance.spec, "helm_wait", true)
  chart            = "${path.module}/charts/nginx-gateway-fabric-2.4.1.tgz"
  namespace        = var.environment.namespace
  max_history      = 10
  skip_crds        = false
  create_namespace = false
  timeout          = 600

  values = [
    yamlencode({
      # Use release-specific TLS secret names to support multiple instances in the same namespace
      certGenerator = {
        serverTLSSecretName = "${local.name}-server-tls"
        agentTLSSecretName  = "${local.name}-agent-tls"
        overwrite           = true
        tolerations         = local.ingress_tolerations
        nodeSelector        = local.nodepool_labels
      }

      nginxGateway = merge({
        # Configure the GatewayClass name
        gatewayClassName = local.gateway_class_name

        # Labels for control plane deployment
        labels = local.common_labels

        image = {
          repository = "facetscloud/nginx-gateway-fabric"
          tag        = "v2.4.1"
          pullPolicy = "IfNotPresent"
        }
        imagePullSecrets = lookup(var.inputs, "artifactories", null) != null ? var.inputs.artifactories.attributes.registry_secrets_list : []

        # Control plane resources
        resources = {
          requests = {
            cpu    = lookup(lookup(lookup(lookup(var.instance.spec, "control_plane", {}), "resources", {}), "requests", {}), "cpu", "200m")
            memory = lookup(lookup(lookup(lookup(var.instance.spec, "control_plane", {}), "resources", {}), "requests", {}), "memory", "256Mi")
          }
          limits = {
            cpu    = lookup(lookup(lookup(lookup(var.instance.spec, "control_plane", {}), "resources", {}), "limits", {}), "cpu", "500m")
            memory = lookup(lookup(lookup(lookup(var.instance.spec, "control_plane", {}), "resources", {}), "limits", {}), "memory", "512Mi")
          }
        }

        # Control plane autoscaling - always enabled
        autoscaling = {
          enable                            = true
          minReplicas                       = lookup(lookup(lookup(var.instance.spec, "control_plane", {}), "scaling", {}), "min_replicas", 2)
          maxReplicas                       = lookup(lookup(lookup(var.instance.spec, "control_plane", {}), "scaling", {}), "max_replicas", 3)
          targetCPUUtilizationPercentage    = lookup(lookup(lookup(var.instance.spec, "control_plane", {}), "scaling", {}), "target_cpu_utilization_percentage", 70)
          targetMemoryUtilizationPercentage = lookup(lookup(lookup(var.instance.spec, "control_plane", {}), "scaling", {}), "target_memory_utilization_percentage", 80)
        }

        tolerations  = local.ingress_tolerations
        nodeSelector = local.nodepool_labels

        # Labels for control plane service
        service = {
          labels = local.common_labels
        }
        },
        # Enable snippets support whenever any SnippetsPolicy or SnippetsFilter is emitted.
        # The proxy-timeouts SnippetsPolicy is emitted unconditionally, so this is effectively
        # always on. The same nginxGateway.snippets.enable flag is required by NGF for BOTH
        # SnippetsPolicy (gateway-level) and SnippetsFilter (per-rule nginx_timeouts) to render.
        length(local.snippetspolicy_resources) > 0 || length(local.snippetsfilter_resources) > 0 ? {
          snippets = {
            enable = true
          }
      } : {})

      # NGINX data plane configuration (NginxProxy)
      # Note: The following fields are NOT supported in NginxProxy CRD (NGF 2.3.0):
      # - clientMaxBodySize (use ClientSettingsPolicy body.maxSize instead)
      # - proxyConnectTimeout, proxySendTimeout, proxyReadTimeout (not exposed in any CRD)
      nginx = {
        # Cloud-specific NginxProxy config (e.g. proxy protocol for AWS)
        # Access logs are always enabled with upstream service name for debugging
        config = merge(
          var.nginx_proxy_extra_config,
          {
            logging = {
              errorLevel = "info"
              agentLevel = "info"
              accessLog = {
                disable = false
                format  = "$remote_addr - $remote_user [$time_local] \"$request\" $status $body_bytes_sent \"$http_referer\" \"$http_user_agent\" $request_length $request_time [$proxy_host] $upstream_addr $upstream_response_length $upstream_response_time $upstream_status"
              }
            }
          }
        )

        # Data plane autoscaling - always enabled
        autoscaling = {
          enable                            = true
          minReplicas                       = lookup(lookup(lookup(var.instance.spec, "data_plane", {}), "scaling", {}), "min_replicas", 2)
          maxReplicas                       = lookup(lookup(lookup(var.instance.spec, "data_plane", {}), "scaling", {}), "max_replicas", 10)
          targetCPUUtilizationPercentage    = lookup(lookup(lookup(var.instance.spec, "data_plane", {}), "scaling", {}), "target_cpu_utilization_percentage", 70)
          targetMemoryUtilizationPercentage = lookup(lookup(lookup(var.instance.spec, "data_plane", {}), "scaling", {}), "target_memory_utilization_percentage", 80)
        }

        # Data plane container resources
        container = {
          resources = {
            requests = {
              cpu    = lookup(lookup(lookup(lookup(var.instance.spec, "data_plane", {}), "resources", {}), "requests", {}), "cpu", "250m")
              memory = lookup(lookup(lookup(lookup(var.instance.spec, "data_plane", {}), "resources", {}), "requests", {}), "memory", "256Mi")
            }
            limits = {
              cpu    = lookup(lookup(lookup(lookup(var.instance.spec, "data_plane", {}), "resources", {}), "limits", {}), "cpu", "1")
              memory = lookup(lookup(lookup(lookup(var.instance.spec, "data_plane", {}), "resources", {}), "limits", {}), "memory", "512Mi")
            }
          }
        }

        # Data plane pod configuration
        pod = {
          tolerations  = local.ingress_tolerations
          nodeSelector = local.nodepool_labels
        }

        # Labels for data plane deployment via patches
        patches = [
          {
            type = "StrategicMerge"
            value = {
              metadata = {
                labels = local.common_labels
              }
            }
          }
        ]

        service = {
          type                  = "LoadBalancer"
          loadBalancerClass     = var.load_balancer_class != "" ? var.load_balancer_class : null
          externalTrafficPolicy = "Cluster"
          # Service patches for annotations and labels
          patches = [
            {
              type = "StrategicMerge"
              value = {
                metadata = {
                  labels      = local.common_labels
                  annotations = var.service_annotations
                }
              }
            }
          ]
        }
      }

      # Gateway configuration
      gateways = [{
        name      = local.name
        namespace = var.environment.namespace
        labels = merge(local.common_labels, {
          "gateway.networking.k8s.io/gateway-name" = local.name
        })
        # Only add cert-manager annotations when using gateway-shim (all domains managed by cert-manager)
        # When custom certs present, no cert-manager annotations needed
        annotations = local.use_gateway_shim ? {
          "cert-manager.io/cluster-issuer" = local.effective_cluster_issuer
          "cert-manager.io/renew-before"   = lookup(var.instance.spec, "renew_cert_before", "720h")
        } : {}
        spec = {
          gatewayClassName = local.gateway_class_name
          listeners = concat(
            # HTTP Listener (always present)
            [{
              name     = "http"
              protocol = "HTTP"
              port     = 80
              allowedRoutes = {
                namespaces = {
                  from = "All"
                }
              }
            }],
            # External TLS mode: single HTTP listener on 443, no hostname restriction, no TLS
            var.external_tls_termination ? [{
              name     = "https"
              protocol = "HTTP"
              port     = 443
              allowedRoutes = {
                namespaces = {
                  from = "All"
                }
              }
            }] : [],
            # cert-manager mode: per-domain HTTPS listeners (see local.https_domain_listeners
            # for the apex-vs-wildcard rationale).
            var.external_tls_termination ? [] : [for l in local.https_domain_listeners : {
              name     = l.name
              protocol = "HTTPS"
              port     = 443
              hostname = l.hostname
              tls = {
                mode = "Terminate"
                certificateRefs = [{
                  kind = "Secret"
                  name = l.secret
                }]
              }
              allowedRoutes = {
                namespaces = {
                  from = "All"
                }
              }
            }],
            # cert-manager mode: HTTPS Listeners for additional hostnames
            var.external_tls_termination ? [] : [for hostname_key, config in local.additional_hostname_configs : {
              name     = "https-${hostname_key}"
              protocol = "HTTPS"
              port     = 443
              hostname = config.hostname
              tls = {
                mode = "Terminate"
                certificateRefs = [{
                  kind = "Secret"
                  name = config.secret_name
                }]
              }
              allowedRoutes = {
                namespaces = {
                  from = "All"
                }
              }
            }]
          )
        }
      }]
    }),
    yamlencode(local.base_helm_values)
  ]

  depends_on = [
    kubernetes_secret_v1.bootstrap_tls,
    kubernetes_secret_v1.bootstrap_tls_additional
  ]

  # saas-cp stays the live owner until handoff; never overwrite its values (1155 incident)
  lifecycle {
    ignore_changes = [values, chart]
  }
}

# Deploy all Gateway API resources using facets-utility-modules
# Release 1: Base infrastructure — policies, monitors, grants, auth filters, snippets, gRPC routes
# Deployed first as HTTPS/HTTP routes may depend on these resources (e.g. AuthenticationFilter, SnippetsPolicy)
module "gateway_api_resources_base" {
  source = "./any-k8s-resources"

  name            = "${local.name}-gateway-api-base"
  release_name    = "${local.name}-gateway-api-base"
  namespace       = var.environment.namespace
  resources_data  = local.gateway_api_resources_base
  advanced_config = {}

  depends_on = [helm_release.nginx_gateway_fabric, kubernetes_secret_v1.basic_auth]
}

# Release 2: HTTPS HTTPRoutes — routes attached to HTTPS listener(s)
# Contains all routes that serve traffic on port 443 (with X-Forwarded-Proto: https when external TLS)
module "gateway_api_resources_https_routes" {
  source = "./any-k8s-resources"

  name            = "${local.name}-gateway-api-https"
  release_name    = "${local.name}-gateway-api-https"
  namespace       = var.environment.namespace
  resources_data  = local.gateway_api_resources_https_routes
  advanced_config = {}

  depends_on = [module.gateway_api_resources_base]
}

# Release 3: HTTP traffic handling
# When force_ssl_redirection = true: single blanket redirect rule (301 HTTP → HTTPS)
# When force_ssl_redirection = false: HTTP listener HTTPRoutes (with X-Forwarded-Proto: http)
module "gateway_api_resources_http_routes" {
  source = "./any-k8s-resources"

  name            = "${local.name}-gateway-api-http"
  release_name    = "${local.name}-gateway-api-http"
  namespace       = var.environment.namespace
  resources_data  = local.gateway_api_resources_http_routes
  advanced_config = {}

  depends_on = [module.gateway_api_resources_base]
}

# Basic Authentication using NGF AuthenticationFilter CRD
# NGF 2.4.1 supports native basic auth via AuthenticationFilter (gateway.nginx.org/v1alpha1)
# When basic_auth is enabled: auto-generates credentials, creates htpasswd Secret,
# and applies AuthenticationFilter to all HTTPRoute rules (per-rule disable_auth to exempt)

resource "random_string" "basic_auth_password" {
  count   = lookup(var.instance.spec, "basic_auth", false) ? 1 : 0
  length  = 10
  special = false
}

resource "kubernetes_secret_v1" "basic_auth" {
  count = lookup(var.instance.spec, "basic_auth", false) ? 1 : 0

  metadata {
    name      = "${local.name}-basic-auth"
    namespace = var.environment.namespace
  }

  data = {
    auth = "${var.instance_name}user:${bcrypt(random_string.basic_auth_password[0].result)}"
  }

  type = "nginx.org/htpasswd"

  lifecycle {
    ignore_changes        = [data]
    create_before_destroy = true
  }
}

# Load Balancer Service Discovery
# Note: The LoadBalancer service is created by NGINX Gateway Fabric controller
# when it processes the Gateway resource from the Helm chart
data "kubernetes_service" "gateway_lb" {
  depends_on = [
    helm_release.nginx_gateway_fabric
  ]
  metadata {
    # NGF controller creates the data-plane LoadBalancer Service named after the
    # Gateway resource itself with the pattern: <gateway-name>-<gateway-name>.
    # This is independent of the helm release name (so helm_release_name_override
    # does NOT affect this lookup).
    name      = "${local.name}-${local.name}"
    namespace = var.environment.namespace
  }
}

# Route53 DNS Records (AWS only)
resource "aws_route53_record" "cluster-base-domain" {
  count = local.tenant_provider == "aws" && !lookup(var.instance.spec, "disable_base_domain", false) ? 1 : 0
  depends_on = [
    helm_release.nginx_gateway_fabric,
    data.kubernetes_service.gateway_lb
  ]
  zone_id  = local.tenant_base_domain_id
  name     = local.base_domain
  type     = local.record_type
  ttl      = "300"
  records  = [local.lb_record_value]
  provider = aws3tooling
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "cluster-base-domain-wildcard" {
  count = local.tenant_provider == "aws" && !lookup(var.instance.spec, "disable_base_domain", false) ? 1 : 0
  depends_on = [
    helm_release.nginx_gateway_fabric,
    data.kubernetes_service.gateway_lb
  ]
  zone_id  = local.tenant_base_domain_id
  name     = local.base_subdomain
  type     = local.record_type
  ttl      = "300"
  records  = [local.lb_record_value]
  provider = aws3tooling
  lifecycle {
    prevent_destroy = true
  }
}
