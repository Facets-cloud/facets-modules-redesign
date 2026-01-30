# Read environment variables directly from shell
data "external" "env_vars" {
  program = ["sh", "-c", <<-EOT
    echo "{\"tenant_base_domain\":\"$TF_VAR_tenant_base_domain\",\"cc_tenant_provider\":\"$TF_VAR_cc_tenant_provider\"}"
  EOT
  ]
}

locals {
  name      = var.instance_name
  namespace = var.instance.spec.namespace
  spec      = var.instance.spec

  # Base domain from environment variable
  tenant_base_domain_value  = coalesce(lookup(data.external.env_vars.result, "tenant_base_domain", ""), "")
  tenant_base_domain_id     = "" # Route53 zone ID not available without cc_metadata
  tenant_provider           = lookup(data.external.env_vars.result, "cc_tenant_provider", "aws")
  has_tenant_base_domain    = local.tenant_base_domain_value != ""
  has_tenant_base_domain_id = local.tenant_base_domain_id != ""

  # DNS record type - CNAME for AWS, A record for others
  record_type = local.tenant_provider == "aws" ? "CNAME" : "A"

  instance_env_name = local.has_tenant_base_domain && (length(var.environment.unique_name) + length(var.instance_name) + length(local.tenant_base_domain_value) >= 60) ? substr(md5("${var.instance_name}-${var.environment.unique_name}"), 0, 20) : "${var.instance_name}-${var.environment.unique_name}"
  base_domain       = local.has_tenant_base_domain ? lower("${local.instance_env_name}.${local.tenant_base_domain_value}") : ""
  base_subdomain    = local.has_tenant_base_domain ? "*.${local.base_domain}" : ""

  # Auto-add base domain if not disabled and tenant_base_domain is provided
  add_base_domain = lookup(local.spec, "disable_base_domain", false) || !local.has_tenant_base_domain ? {} : {
    "facets-base" = {
      domain    = local.base_domain
      alias     = "base"
      auto_cert = true
    }
  }

  # Extract configuration sections - merge base domain with user-defined domains
  domains                 = merge(lookup(local.spec, "domains", {}), local.add_base_domain)
  rules                   = lookup(local.spec, "rules", {})
  global_response_headers = lookup(local.spec, "global_response_headers", {})
  global_header_routing   = lookup(local.spec, "global_header_routing", {})
  ip_whitelist            = lookup(local.spec, "ip_whitelist", {})
  custom_errors           = lookup(local.spec, "custom_error_pages", {})
  resources_config        = lookup(local.spec, "resources", {})
  autoscaling             = lookup(local.spec, "autoscaling", {})

  # Build complete host -> domain mapping
  domain_mappings = merge([
    for domain_key, domain_config in local.domains : {
      for rule_key, rule in local.rules :
      "${lookup(rule, "domain_prefix", "*")}.${domain_config.domain}" => {
        domain_key    = domain_key
        domain_config = domain_config
        host          = lookup(rule, "domain_prefix", "*") == "*" ? domain_config.domain : "${lookup(rule, "domain_prefix", "*")}.${domain_config.domain}"
        is_wildcard   = lookup(rule, "domain_prefix", "*") == "*"
      }
      if !lookup(rule, "disable", false)
    }
  ]...)

  # Flatten rules for easier iteration
  active_rules = {
    for rule_key, rule in local.rules : rule_key => rule
    if !lookup(rule, "disable", false)
  }

  # Collect ACM certificate ARNs from domains (for NLB TLS termination)
  acm_certificate_arns = [
    for domain_key, domain_config in local.domains :
    lookup(domain_config, "acm_certificate_arn", "")
    if lookup(domain_config, "acm_certificate_arn", "") != ""
  ]

  # Service annotation merging
  service_annotations = merge(
    lookup(local.spec, "global_annotations", {}),
    {
      "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = lookup(local.spec, "private", false) ? "internal" : "internet-facing"
      "service.beta.kubernetes.io/aws-load-balancer-internal"                          = lookup(local.spec, "private", false) ? "true" : "false"
    },
    # Enable Proxy Protocol v2 for real client IP when IP whitelist is enabled
    lookup(local.ip_whitelist, "enabled", false) ? {
      "service.beta.kubernetes.io/aws-load-balancer-target-group-attributes" = "proxy_protocol_v2.enabled=true"
    } : {},
    # Add ACM certificate ARN for TLS termination at load balancer
    length(local.acm_certificate_arns) > 0 ? {
      "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"  = join(",", local.acm_certificate_arns)
      "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" = "443"
    } : {}
  )
}

# Cert-manager Certificate for base domain (automatic TLS)
# This creates a Certificate resource that cert-manager will fulfill
# Only created when use_cert_manager is enabled (cert_manager is assumed to be installed)
module "base_domain_certificate" {
  count = (
    local.has_tenant_base_domain &&
    !lookup(local.spec, "disable_base_domain", false) &&
    lookup(lookup(local.spec, "certificate", {}), "use_cert_manager", false)
  ) ? 1 : 0

  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${local.name}-base-domain-cert"
  namespace       = local.namespace
  advanced_config = {}
  release_name    = "${local.name}-base-domain-cert"
  data = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "${local.name}-base-domain-cert"
      namespace = local.namespace
      labels = {
        "app.kubernetes.io/name"       = "traefik"
        "app.kubernetes.io/instance"   = local.name
        "app.kubernetes.io/managed-by" = "facets"
      }
    }
    spec = {
      secretName = "${local.name}-base-domain-tls"
      issuerRef = {
        name = lookup(lookup(local.spec, "certificate", {}), "issuer_name", "letsencrypt-prod")
        kind = lookup(lookup(local.spec, "certificate", {}), "issuer_kind", "ClusterIssuer")
      }
      dnsNames = [
        local.base_domain,
        local.base_subdomain
      ]
    }
  }

  depends_on = [helm_release.traefik]
}

# Deploy Traefik using Helm with Gateway API support
resource "helm_release" "traefik" {
  name             = local.name
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = lookup(local.spec, "ingress_chart_version", "38.0.2")
  namespace        = local.namespace
  create_namespace = lookup(local.spec, "create_namespace", true)
  skip_crds        = true

  # Wait for CRDs to be installed first
  depends_on = [helm_release.traefik_crds, null_resource.gateway_api_crds]

  values = [
    yamlencode({
      deployment = {
        # When autoscaling is enabled, use min_replicas as initial; otherwise use replicas
        replicas = lookup(local.autoscaling, "enabled", false) ? lookup(local.autoscaling, "min_replicas", 2) : lookup(local.spec, "replicas", 2)
      }

      # Autoscaling (HPA) configuration
      autoscaling = lookup(local.autoscaling, "enabled", false) ? {
        enabled     = true
        minReplicas = lookup(local.autoscaling, "min_replicas", 2)
        maxReplicas = lookup(local.autoscaling, "max_replicas", 10)
        metrics = concat(
          [{
            type = "Resource"
            resource = {
              name = "cpu"
              target = {
                type               = "Utilization"
                averageUtilization = lookup(local.autoscaling, "target_cpu_utilization_percent", 80)
              }
            }
          }],
          lookup(local.autoscaling, "target_memory_utilization_percent", null) != null ? [{
            type = "Resource"
            resource = {
              name = "memory"
              target = {
                type               = "Utilization"
                averageUtilization = lookup(local.autoscaling, "target_memory_utilization_percent", 80)
              }
            }
          }] : []
        )
      } : {
        enabled = false
      }

      # Disable default ingressClass - we use Gateway API
      ingressClass = {
        enabled = false
      }

      # Enable Gateway API provider
      providers = {
        kubernetesGateway = {
          enabled = true
          # Don't require experimental CRDs (BackendTLSPolicy, etc.)
          experimentalChannel = false
        }
        # Keep CRD provider for Middleware resources
        kubernetesCRD = {
          enabled             = true
          allowCrossNamespace = lookup(local.spec, "grpc", false)
        }
        # Disable default kubernetes ingress provider
        kubernetesIngress = {
          enabled = false
        }
      }

      # Disable default gateway - we create our own
      gateway = {
        enabled = false
      }

      # Create GatewayClass
      gatewayClass = {
        enabled = true
        name    = local.name
      }

      service = {
        type        = lookup(local.spec, "service_type", "LoadBalancer")
        annotations = local.service_annotations
      }

      ports = {
        web = {
          port        = 8000
          exposedPort = 80
          protocol    = "TCP"
          expose = {
            default = true
          }
          forwardedHeaders = {
            trustedIPs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
          }
          proxyProtocol = {
            trustedIPs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
          }
        }
        websecure = {
          port        = 8443
          exposedPort = 443
          protocol    = "TCP"
          expose = {
            default = true
          }
          forwardedHeaders = {
            trustedIPs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
          }
          proxyProtocol = {
            trustedIPs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
          }
          tls = {
            enabled = true
          }
        }
      }

      resources = {
        requests = {
          cpu    = lookup(lookup(local.resources_config, "requests", {}), "cpu", "100m")
          memory = lookup(lookup(local.resources_config, "requests", {}), "memory", "128Mi")
        }
        limits = {
          cpu    = lookup(lookup(local.resources_config, "limits", {}), "cpu", "500m")
          memory = lookup(lookup(local.resources_config, "limits", {}), "memory", "512Mi")
        }
      }

      logs = {
        general = {
          level = "INFO"
        }
        access = {
          enabled = true
        }
      }
    })
  ]
}

# Gateway resource - defines listeners (entry points) for HTTP and HTTPS
module "gateway" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = local.name
  namespace       = local.namespace
  advanced_config = {}
  release_name    = "${local.name}-gateway"
  data = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = local.name
      namespace = local.namespace
      labels = {
        "app.kubernetes.io/name"       = "traefik"
        "app.kubernetes.io/instance"   = local.name
        "app.kubernetes.io/managed-by" = "facets"
      }
    }
    spec = {
      gatewayClassName = local.name
      listeners = [
        # HTTP listener - port must match Traefik's web entrypoint (8000)
        {
          name     = "web"
          port     = 8000
          protocol = "HTTP"
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
        },
        # HTTPS listener - port must match Traefik's websecure entrypoint (8443)
        {
          name     = "websecure"
          port     = 8443
          protocol = "HTTPS"
          tls = {
            mode = "Terminate"
            # Only reference cert if using cert-manager, otherwise Traefik uses default cert
            certificateRefs = local.has_tenant_base_domain && lookup(lookup(local.spec, "certificate", {}), "use_cert_manager", false) ? [{
              kind      = "Secret"
              name      = "${local.name}-base-domain-tls"
              namespace = local.namespace
            }] : []
          }
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.traefik, module.base_domain_certificate]
}

# Global Response Headers Middleware
module "global_response_headers" {
  count = length(keys(local.global_response_headers)) > 0 ? 1 : 0

  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${local.name}-global-headers"
  namespace       = local.namespace
  advanced_config = {}
  release_name    = "${local.name}-global-headers"
  data = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "${local.name}-global-headers"
      namespace = local.namespace
    }
    spec = {
      headers = {
        customResponseHeaders = local.global_response_headers
      }
    }
  }

  depends_on = [helm_release.traefik]
}

# Global IP Whitelist Middleware for monitoring endpoints
module "ip_whitelist_monitoring" {
  count = lookup(local.ip_whitelist, "enabled", false) ? 1 : 0

  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${local.name}-ip-whitelist-monitoring"
  namespace       = local.namespace
  advanced_config = {}
  release_name    = "${local.name}-ip-whitelist-monitoring"
  data = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "${local.name}-ip-whitelist-monitoring"
      namespace = local.namespace
    }
    spec = {
      ipWhiteList = {
        sourceRange = lookup(local.ip_whitelist, "allowed_ips", [])
      }
    }
  }

  depends_on = [helm_release.traefik]
}

# Basic Auth Middleware
module "basic_auth" {
  count = lookup(local.spec, "basic_auth", false) ? 1 : 0

  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${local.name}-basic-auth"
  namespace       = local.namespace
  advanced_config = {}
  release_name    = "${local.name}-basic-auth"
  data = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "${local.name}-basic-auth"
      namespace = local.namespace
    }
    spec = {
      basicAuth = {
        secret = lookup(local.spec, "basic_auth_secret", "")
      }
    }
  }

  depends_on = [helm_release.traefik]
}

# Strip Prefix Middleware per rule
module "strip_prefix" {
  for_each = {
    for rule_key, rule in local.active_rules : rule_key => rule
    if lookup(rule, "enable_rewrite_target", false)
  }

  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${local.name}-strip-${each.key}"
  namespace       = local.namespace
  advanced_config = {}
  release_name    = "${local.name}-strip-${each.key}"
  data = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "${local.name}-strip-${each.key}"
      namespace = local.namespace
    }
    spec = {
      stripPrefix = {
        prefixes = [lookup(each.value, "path", "/")]
      }
    }
  }

  depends_on = [helm_release.traefik]
}


# CORS Middleware per rule
module "cors" {
  for_each = {
    for rule_key, rule in local.active_rules : rule_key => rule
    if lookup(lookup(rule, "cors", {}), "enable", false)
  }

  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${local.name}-cors-${each.key}"
  namespace       = local.namespace
  advanced_config = {}
  release_name    = "${local.name}-cors-${each.key}"
  data = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "${local.name}-cors-${each.key}"
      namespace = local.namespace
    }
    spec = {
      headers = {
        accessControlAllowOriginList  = lookup(each.value.cors, "allowed_origins", ["*"])
        accessControlAllowMethods     = lookup(each.value.cors, "allowed_methods", ["GET", "POST", "PUT", "DELETE", "OPTIONS"])
        accessControlAllowHeaders     = length(lookup(each.value.cors, "allowed_headers", [])) > 0 ? lookup(each.value.cors, "allowed_headers", []) : ["*"]
        accessControlExposeHeaders    = ["*"]
        accessControlAllowCredentials = true
        accessControlMaxAge           = 100
        addVaryHeader                 = true
      }
    }
  }

  depends_on = [helm_release.traefik]
}

# Rule-level Response Headers Middleware
module "response_headers" {
  for_each = {
    for rule_key, rule in local.active_rules : rule_key => rule
    if length(lookup(rule, "response_headers", {})) > 0
  }

  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${local.name}-resp-headers-${each.key}"
  namespace       = local.namespace
  advanced_config = {}
  release_name    = "${local.name}-resp-headers-${each.key}"
  data = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "${local.name}-resp-headers-${each.key}"
      namespace = local.namespace
    }
    spec = {
      headers = {
        customResponseHeaders = lookup(each.value, "response_headers", {})
      }
    }
  }

  depends_on = [helm_release.traefik]
}

# TraefikService for every rule (with or without sticky session)
module "traefik_service" {
  for_each = local.active_rules

  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${local.name}-svc-${each.key}"
  namespace       = local.namespace
  advanced_config = {}
  release_name    = "${local.name}-svc-${each.key}"
  data = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "TraefikService"
    metadata = {
      name      = "${local.name}-svc-${each.key}"
      namespace = local.namespace
      labels = {
        "app.kubernetes.io/managed-by" = "facets"
        "rule-name"                    = each.key
      }
    }
    spec = {
      weighted = {
        services = [merge(
          {
            name   = lookup(each.value, "service_name", "")
            port   = tonumber(lookup(each.value, "port", "80"))
            weight = 1
          },
          # Add sticky config only if session_affinity is configured
          lookup(lookup(each.value, "session_affinity", {}), "session_cookie_name", "") != "" ? {
            sticky = {
              cookie = {
                name     = lookup(lookup(each.value, "session_affinity", {}), "session_cookie_name", "route")
                secure   = true
                httpOnly = true
                maxAge   = tonumber(lookup(lookup(each.value, "session_affinity", {}), "session_cookie_max_age", "3600"))
              }
            }
          } : {}
        )]
      }
    }
  }

  depends_on = [helm_release.traefik]
}

# Custom error pages ConfigMap
resource "kubernetes_config_map" "error_pages" {
  count = length(local.custom_errors) > 0 ? 1 : 0

  metadata {
    name      = "${local.name}-error-pages"
    namespace = local.namespace
  }

  data = {
    for error_key, error_config in local.custom_errors :
    "${error_config.error_code}.html" => error_config.page_content
  }

  depends_on = [helm_release.traefik]
}

# Error page service (nginx serving static error pages)
resource "kubernetes_deployment" "error_pages" {
  count = length(local.custom_errors) > 0 ? 1 : 0

  metadata {
    name      = "${local.name}-error-pages"
    namespace = local.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "${local.name}-error-pages"
      }
    }

    template {
      metadata {
        labels = {
          app = "${local.name}-error-pages"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:alpine"

          port {
            container_port = 80
          }

          volume_mount {
            name       = "error-pages"
            mount_path = "/usr/share/nginx/html"
          }
        }

        volume {
          name = "error-pages"
          config_map {
            name = kubernetes_config_map.error_pages[0].metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_config_map.error_pages]
}

resource "kubernetes_service" "error_pages" {
  count = length(local.custom_errors) > 0 ? 1 : 0

  metadata {
    name      = "${local.name}-error-pages"
    namespace = local.namespace
  }

  spec {
    selector = {
      app = "${local.name}-error-pages"
    }

    port {
      port        = 80
      target_port = 80
    }
  }

  depends_on = [kubernetes_deployment.error_pages]
}

# Error Pages Middleware
module "error_pages_middleware" {
  count = length(local.custom_errors) > 0 ? 1 : 0

  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${local.name}-errors"
  namespace       = local.namespace
  advanced_config = {}
  release_name    = "${local.name}-errors"
  data = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "${local.name}-errors"
      namespace = local.namespace
    }
    spec = {
      errors = {
        status = [for error_key, error_config in local.custom_errors : error_config.error_code]
        query  = "/{status}.html"
        service = {
          name = kubernetes_service.error_pages[0].metadata[0].name
          port = 80
        }
      }
    }
  }

  depends_on = [kubernetes_service.error_pages, helm_release.traefik]
}

# Build IngressRoutes for each rule
locals {
  # Get first domain for host construction
  first_domain_key = length(keys(local.domains)) > 0 ? keys(local.domains)[0] : ""
  first_domain     = local.first_domain_key != "" ? local.domains[local.first_domain_key] : null

  # Group rules by host
  rules_by_host = {
    for rule_key, rule in local.active_rules :
    rule_key => {
      host = local.first_domain != null ? (
        lookup(rule, "domain_prefix", "*") == "*" ? lookup(local.first_domain, "domain", "") : "${lookup(rule, "domain_prefix", "*")}.${lookup(local.first_domain, "domain", "")}"
      ) : ""
      rule     = rule
      rule_key = rule_key
      domain_data = local.first_domain != null ? {
        domain_key = local.first_domain_key
        config     = local.first_domain
        } : {
        domain_key = ""
        config     = null
      }
    }
  }


  # Build middleware chain for each rule
  rule_middlewares = {
    for rule_key, rule in local.active_rules : rule_key => concat(
      # Global response headers
      length(keys(local.global_response_headers)) > 0 ? ["${local.name}-global-headers"] : [],

      # Basic auth
      lookup(local.spec, "basic_auth", false) ? ["${local.name}-basic-auth"] : [],

      # Strip prefix
      lookup(rule, "enable_rewrite_target", false) ? ["${local.name}-strip-${rule_key}"] : [],

      # CORS
      lookup(lookup(rule, "cors", {}), "enable", false) ? ["${local.name}-cors-${rule_key}"] : [],

      # Error pages
      length(local.custom_errors) > 0 ? ["${local.name}-errors"] : []
    )
  }
}

# HTTPRoute for each rule (Kubernetes Gateway API)
module "http_routes" {
  for_each = local.rules_by_host

  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${local.name}-${each.key}"
  namespace       = local.namespace
  advanced_config = {}
  release_name    = "${local.name}-route-${each.key}"
  data = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "${local.name}-${each.key}"
      namespace = local.namespace
      labels = {
        "app.kubernetes.io/managed-by" = "facets"
        "rule-name"                    = each.key
      }
      annotations = lookup(each.value.rule, "annotations", {})
    }
    spec = {
      # Reference to the parent Gateway (no sectionName = attach to all listeners)
      parentRefs = [{
        name      = local.name
        namespace = local.namespace
      }]

      # Hostnames for this route
      hostnames = [each.value.host]

      # Routing rules
      rules = [{
        # Match conditions - combine path AND headers in single match (AND logic)
        matches = [{
          path = {
            type  = "PathPrefix"
            value = lookup(each.value.rule, "path", "/")
          }
          # Include headers only if header-based routing is enabled (combines with path as AND)
          headers = concat(
            # Global header rules
            lookup(local.global_header_routing, "enabled", false) ? [
              for hr_key, hr in lookup(local.global_header_routing, "rules", {}) : {
                name  = hr.header_name
                value = hr.header_value
                type  = lookup(hr, "match_type", "exact") == "regex" ? "RegularExpression" : "Exact"
              }
            ] : [],
            # Per-rule header rules
            lookup(each.value.rule, "enable_header_based_routing", false) ? [
              for hr_key, hr in lookup(each.value.rule, "header_routing_rules", {}) : {
                name  = hr.header_name
                value = hr.header_value
                type  = lookup(hr, "match_type", "exact") == "regex" ? "RegularExpression" : "Exact"
              }
            ] : []
          )
        }]

        # Backend service references - always use TraefikService
        backendRefs = [{
          group = "traefik.io"
          kind  = "TraefikService"
          name  = "${local.name}-svc-${each.key}"
        }]

        # Filters (middlewares via ExtensionRef)
        filters = concat(
          # Global response headers middleware
          length(keys(local.global_response_headers)) > 0 ? [{
            type = "ExtensionRef"
            extensionRef = {
              group = "traefik.io"
              kind  = "Middleware"
              name  = "${local.name}-global-headers"
            }
          }] : [],

          # Basic auth middleware
          lookup(local.spec, "basic_auth", false) ? [{
            type = "ExtensionRef"
            extensionRef = {
              group = "traefik.io"
              kind  = "Middleware"
              name  = "${local.name}-basic-auth"
            }
          }] : [],

          # Strip prefix middleware (URL rewrite)
          lookup(each.value.rule, "enable_rewrite_target", false) ? [{
            type = "ExtensionRef"
            extensionRef = {
              group = "traefik.io"
              kind  = "Middleware"
              name  = "${local.name}-strip-${each.key}"
            }
          }] : [],

          # CORS middleware
          lookup(lookup(each.value.rule, "cors", {}), "enable", false) ? [{
            type = "ExtensionRef"
            extensionRef = {
              group = "traefik.io"
              kind  = "Middleware"
              name  = "${local.name}-cors-${each.key}"
            }
          }] : [],

          # Rule-level response headers middleware
          length(lookup(each.value.rule, "response_headers", {})) > 0 ? [{
            type = "ExtensionRef"
            extensionRef = {
              group = "traefik.io"
              kind  = "Middleware"
              name  = "${local.name}-resp-headers-${each.key}"
            }
          }] : [],

          # Error pages middleware
          length(local.custom_errors) > 0 ? [{
            type = "ExtensionRef"
            extensionRef = {
              group = "traefik.io"
              kind  = "Middleware"
              name  = "${local.name}-errors"
            }
          }] : []
        )
      }]
    }
  }

  depends_on = [
    helm_release.traefik,
    module.gateway,
    module.traefik_service,
    module.global_response_headers,
    module.ip_whitelist_monitoring,
    module.basic_auth,
    module.strip_prefix,
    module.cors,
    module.response_headers,
    module.error_pages_middleware,
    module.base_domain_certificate
  ]
}

# IP Whitelist Protected Paths IngressRoutes
locals {
  ip_whitelist_enabled = lookup(local.ip_whitelist, "enabled", false)
  ip_whitelist_paths   = lookup(local.ip_whitelist, "protected_paths", [])
}

# IP Whitelist Protected Paths HTTPRoutes (Kubernetes Gateway API)
module "ip_whitelist_routes" {
  for_each = {
    for pair in setproduct(
      local.ip_whitelist_enabled ? keys(local.rules_by_host) : [],
      local.ip_whitelist_enabled ? local.ip_whitelist_paths : []
    ) :
    "${pair[0]}-${replace(replace(pair[1], "/", ""), ".", "-")}" => {
      rule_key  = pair[0]
      rule_data = local.rules_by_host[pair[0]]
      path      = startswith(pair[1], "/") ? pair[1] : "/${pair[1]}"
    }
  }

  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${local.name}-ipwl-${each.key}"
  namespace       = local.namespace
  advanced_config = {}
  release_name    = "${local.name}-ipwl-${each.key}"
  data = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "${local.name}-ipwl-${each.key}"
      namespace = local.namespace
      labels = {
        "app.kubernetes.io/managed-by" = "facets"
        "ip-whitelist-protected"       = "true"
      }
    }
    spec = {
      # Reference to the parent Gateway (no sectionName = attach to all listeners)
      parentRefs = [{
        name      = local.name
        namespace = local.namespace
      }]

      # Hostnames for this route
      hostnames = [each.value.rule_data.host]

      # Routing rules with IP whitelist
      rules = [{
        # Match on the protected path
        matches = [{
          path = {
            type  = "PathPrefix"
            value = each.value.path
          }
        }]

        # Backend service references
        backendRefs = [{
          name      = lookup(each.value.rule_data.rule, "service_name", "")
          namespace = lookup(each.value.rule_data.rule, "namespace", local.namespace)
          port      = tonumber(lookup(each.value.rule_data.rule, "port", "80"))
        }]

        # IP Whitelist middleware via ExtensionRef
        filters = [{
          type = "ExtensionRef"
          extensionRef = {
            group = "traefik.io"
            kind  = "Middleware"
            name  = "${local.name}-ip-whitelist-monitoring"
          }
        }]
      }]
    }
  }

  depends_on = [
    helm_release.traefik,
    module.gateway,
    module.ip_whitelist_monitoring
  ]
}

# Pod Disruption Budget
resource "kubernetes_pod_disruption_budget_v1" "traefik" {
  count = lookup(local.spec, "pdb", null) != null ? 1 : 0

  metadata {
    name      = "${local.name}-pdb"
    namespace = local.namespace
  }

  spec {
    max_unavailable = lookup(lookup(local.spec, "pdb", {}), "maxUnavailable", null)
    min_available   = lookup(lookup(local.spec, "pdb", {}), "minAvailable", null)

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "traefik"
        "app.kubernetes.io/instance" = local.name
      }
    }
  }

  depends_on = [helm_release.traefik]
}

# Data source to get the Traefik service details
data "kubernetes_service" "traefik" {
  metadata {
    name      = local.name
    namespace = local.namespace
  }

  depends_on = [helm_release.traefik]
}

# Route53 DNS record for base domain
resource "aws_route53_record" "base_domain" {
  count = local.has_tenant_base_domain && local.has_tenant_base_domain_id && local.tenant_provider == "aws" ? 1 : 0

  zone_id  = local.tenant_base_domain_id
  name     = local.base_domain
  type     = local.record_type
  ttl      = 300
  provider = aws3tooling

  records = [
    local.record_type == "CNAME" ?
    data.kubernetes_service.traefik.status[0].load_balancer[0].ingress[0].hostname :
    data.kubernetes_service.traefik.status[0].load_balancer[0].ingress[0].ip
  ]

  depends_on = [helm_release.traefik]

  lifecycle {
    prevent_destroy = true
  }
}

# Route53 DNS record for wildcard subdomain
resource "aws_route53_record" "wildcard_subdomain" {
  count = local.has_tenant_base_domain && local.has_tenant_base_domain_id && local.tenant_provider == "aws" ? 1 : 0

  zone_id  = local.tenant_base_domain_id
  name     = local.base_subdomain
  type     = local.record_type
  ttl      = 300
  provider = aws3tooling

  records = [
    local.record_type == "CNAME" ?
    data.kubernetes_service.traefik.status[0].load_balancer[0].ingress[0].hostname :
    data.kubernetes_service.traefik.status[0].load_balancer[0].ingress[0].ip
  ]

  depends_on = [helm_release.traefik]

  lifecycle {
    prevent_destroy = true
  }
}
