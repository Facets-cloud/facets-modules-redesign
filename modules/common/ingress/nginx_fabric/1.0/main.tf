locals {
  tenant_provider  = lower(lookup(var.cc_metadata, "cc_tenant_provider", "aws"))
  base_helm_values = lookup(var.instance.spec, "helm_values", {})

  # Load balancer configuration - determine record type based on what's actually available
  lb_hostname     = try(data.kubernetes_service.gateway_lb.status[0].load_balancer[0].ingress[0].hostname, "")
  lb_ip           = try(data.kubernetes_service.gateway_lb.status[0].load_balancer[0].ingress[0].ip, "")
  record_type     = local.lb_hostname != "" ? "CNAME" : "A"
  lb_record_value = local.lb_hostname != "" ? local.lb_hostname : local.lb_ip

  # Rules configuration
  rulesRaw = lookup(var.instance.spec, "rules", {})

  # Domain configuration (same as nginx_k8s)
  instance_env_name          = length(var.environment.unique_name) + length(var.instance_name) + length(var.cc_metadata.tenant_base_domain) >= 60 ? substr(md5("${var.instance_name}-${var.environment.unique_name}"), 0, 20) : "${var.instance_name}-${var.environment.unique_name}"
  check_domain_prefix        = coalesce(lookup(var.instance.spec, "domain_prefix_override", null), local.instance_env_name)
  base_domain                = lower("${local.check_domain_prefix}.${var.cc_metadata.tenant_base_domain}")
  base_subdomain             = "*.${local.base_domain}"
  name                       = lower(var.environment.namespace == "default" ? "${var.instance_name}" : "${var.environment.namespace}-${var.instance_name}")
  dns_validation_secret_name = lower("nginx-gateway-fabric-cert-${local.name}")
  gateway_class_name         = lookup(var.instance.spec, "gateway_class_name", local.name)

  # Conditionally append base domain
  add_base_domain = lookup(var.instance.spec, "disable_base_domain", false) ? {} : {
    "facets" = {
      "domain"                = "${local.base_domain}"
      "alias"                 = "base"
      "certificate_reference" = local.dns_validation_secret_name
    }
  }

  domains = merge(lookup(var.instance.spec, "domains", {}), local.add_base_domain)

  # Filter rules
  rulesFiltered = {
    for k, v in local.rulesRaw : length(k) < 175 ? k : md5(k) => merge(v, {
      host       = lookup(v, "domain_prefix", null) == null || lookup(v, "domain_prefix", null) == "" ? "${local.base_domain}" : "${lookup(v, "domain_prefix", null)}.${local.base_domain}"
      domain_key = "facets"
      namespace  = lookup(v, "namespace", var.environment.namespace) # Default namespace if not provided
    })
    if(
      (lookup(v, "port", null) != null && lookup(v, "port", null) != "") &&
      (lookup(v, "service_name", null) != null && lookup(v, "service_name", "") != "") &&
      (lookup(v, "path", null) != null && lookup(v, "path", "") != "") &&
      (lookup(v, "path_type", null) != null && lookup(v, "path_type", "") != "") &&
      (lookup(v, "disable", false) == false)
    )
  }

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

  disable_endpoint_validation = lookup(var.instance.spec, "disable_endpoint_validation", false) || lookup(var.instance.spec, "private", false)

  # Domains that need bootstrap TLS certificates for HTTP-01 validation
  # Bootstrap cert is needed when HTTP-01 validation is used (disable_endpoint_validation = false)
  # For HTTP-01, certificate_reference is ignored (same as nginx_k8s_native) - always auto-generate
  # Bootstrap cert is NOT needed for DNS-01 (uses dns_validation_secret_name)
  bootstrap_tls_domains = {
    for domain_key, domain in local.domains :
    domain_key => domain
    if !local.disable_endpoint_validation
  }

  # Cloud-specific service annotations
  aws_annotations = merge(
    lookup(var.instance.spec, "private", false) ? {
      "service.beta.kubernetes.io/aws-load-balancer-scheme"   = "internal"
      "service.beta.kubernetes.io/aws-load-balancer-internal" = "true"
      } : {
      "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
    },
    {
      "service.beta.kubernetes.io/aws-load-balancer-type"                    = "external"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"         = "ip"
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"        = "http"
      "service.beta.kubernetes.io/aws-load-balancer-target-group-attributes" = lookup(var.instance.spec, "private", false) ? "proxy_protocol_v2.enabled=true,preserve_client_ip.enabled=false" : "proxy_protocol_v2.enabled=true,preserve_client_ip.enabled=true"
    }
  )

  azure_annotations = lookup(var.instance.spec, "private", false) ? {
    "service.beta.kubernetes.io/azure-load-balancer-internal" = "true"
  } : {}

  gcp_annotations = lookup(var.instance.spec, "private", false) ? {
    "cloud.google.com/load-balancer-type"                          = "Internal"
    "networking.gke.io/load-balancer-type"                         = "Internal"
    "networking.gke.io/internal-load-balancer-allow-global-access" = "true"
  } : {}

  cloud_provider = upper(try(var.inputs.kubernetes_details.attributes.cloud_provider, "aws"))

  service_annotations = merge(
    local.cloud_provider == "AWS" ? local.aws_annotations : {},
    local.cloud_provider == "AZURE" ? local.azure_annotations : {},
    local.cloud_provider == "GCP" ? local.gcp_annotations : {}
  )

  # Get ClusterIssuer names and config from cert-manager
  cluster_issuer_dns          = lookup(var.inputs, "cert_manager_details", null) != null ? var.inputs.cert_manager_details.attributes.cluster_issuer_dns : "letsencrypt-prod"
  cluster_issuer_http         = lookup(var.inputs, "cert_manager_details", null) != null ? var.inputs.cert_manager_details.attributes.cluster_issuer_http : "letsencrypt-prod-http01"
  cluster_issuer_gateway_http = "${local.name}-gateway-http01"
  acme_email                  = lookup(var.inputs, "cert_manager_details", null) != null ? var.inputs.cert_manager_details.attributes.acme_email : try(var.cluster.createdBy, "admin@example.com")

  # Security headers
  security_headers = merge(
    lookup(lookup(lookup(var.instance.spec, "security", {}), "security_headers", {}), "hsts_enabled", true) ? {
      "Strict-Transport-Security" = "max-age=${lookup(lookup(lookup(var.instance.spec, "security", {}), "security_headers", {}), "hsts_max_age", 31536000)}; includeSubDomains"
    } : {},
    lookup(lookup(lookup(var.instance.spec, "security", {}), "security_headers", {}), "x_frame_options", null) != null ? {
      "X-Frame-Options" = lookup(lookup(lookup(var.instance.spec, "security", {}), "security_headers", {}), "x_frame_options", "DENY")
    } : {},
    lookup(lookup(lookup(var.instance.spec, "security", {}), "security_headers", {}), "x_content_type_options", true) ? {
      "X-Content-Type-Options" = "nosniff"
    } : {},
    lookup(lookup(lookup(var.instance.spec, "security", {}), "security_headers", {}), "x_xss_protection", true) ? {
      "X-XSS-Protection" = "1; mode=block"
    } : {}
  )

  # CORS headers per route
  cors_headers = {
    for k, v in local.rulesFiltered : k => merge(
      lookup(lookup(v, "cors", {}), "enabled", false) ? {
        "Access-Control-Allow-Origin"  = join(", ", lookup(lookup(v, "cors", {}), "allow_origins", ["*"]))
        "Access-Control-Allow-Methods" = join(", ", lookup(lookup(v, "cors", {}), "allow_methods", ["GET", "POST", "PUT", "DELETE", "OPTIONS"]))
        "Access-Control-Allow-Headers" = join(", ", lookup(lookup(v, "cors", {}), "allow_headers", ["Content-Type", "Authorization"]))
        "Access-Control-Max-Age"       = tostring(lookup(lookup(v, "cors", {}), "max_age", 86400))
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

  # HTTPRoute Resources (HTTPS traffic - port 443)
  # Note: GatewayClass, Gateway, and NginxProxy are created by the Helm chart
  httproute_resources = {
    for k, v in local.rulesFiltered : "httproute-${lower(var.instance_name)}-${k}" => {
      apiVersion = "gateway.networking.k8s.io/v1"
      kind       = "HTTPRoute"
      metadata = {
        name      = "${lower(var.instance_name)}-${k}"
        namespace = var.environment.namespace
      }
      spec = {
        parentRefs = [{
          name        = local.name
          namespace   = var.environment.namespace
          sectionName = lookup(v, "domain_prefix", null) != null ? "https-${v.domain_key}" : "https-facets"
        }]

        hostnames = [v.host]

        rules = [{
          matches = concat(
            # Path matching
            [{
              path = {
                type  = lookup(v, "path_type", "PathPrefix")
                value = lookup(v, "path", "/")
              }
            }],
            # Header matching
            lookup(v, "header_matches", null) != null ? [
              for header in v.header_matches : {
                headers = [{
                  name  = header.name
                  value = header.value
                  type  = lookup(header, "type", "Exact")
                }]
              }
            ] : []
          )

          filters = [
            for filter in [
              # Request header modification
              lookup(v, "request_header_modifier", null) != null ? {
                type = "RequestHeaderModifier"
                requestHeaderModifier = merge(
                  lookup(v.request_header_modifier, "add", null) != null ? {
                    add = [for name, value in v.request_header_modifier.add : { name = name, value = value }]
                  } : {},
                  lookup(v.request_header_modifier, "set", null) != null ? {
                    set = [for name, value in v.request_header_modifier.set : { name = name, value = value }]
                  } : {},
                  lookup(v.request_header_modifier, "remove", null) != null ? {
                    remove = v.request_header_modifier.remove
                  } : {}
                )
              } : null,

              # Response header modification (CORS + custom headers + security headers)
              (lookup(v, "response_header_modifier", null) != null ||
                lookup(lookup(v, "cors", {}), "enabled", false) ||
                length(local.security_headers) > 0) ? {
                type = "ResponseHeaderModifier"
                responseHeaderModifier = merge(
                  length(merge(
                    lookup(lookup(v, "response_header_modifier", {}), "add", {}),
                    local.cors_headers[k],
                    local.security_headers
                    )) > 0 ? {
                    add = [for name, value in merge(
                      lookup(lookup(v, "response_header_modifier", {}), "add", {}),
                      local.cors_headers[k],
                      local.security_headers
                    ) : { name = name, value = value }]
                  } : {},
                  lookup(lookup(v, "response_header_modifier", {}), "set", null) != null ? {
                    set = [for name, value in v.response_header_modifier.set : { name = name, value = value }]
                  } : {},
                  lookup(lookup(v, "response_header_modifier", {}), "remove", null) != null ? {
                    remove = v.response_header_modifier.remove
                  } : {}
                )
              } : null,

              # URL rewriting
              lookup(v, "url_rewrite", null) != null ? {
                type = "URLRewrite"
                urlRewrite = {
                  hostname = lookup(v.url_rewrite, "hostname", null)
                  path     = lookup(v.url_rewrite, "path", null)
                }
              } : null
              # Note: SSL redirection is handled by separate http_redirect_resources HTTPRoutes
              # RequestRedirect filter cannot be used together with backendRefs in the same rule
            ] : filter if filter != null
          ]

          backendRefs = concat(
            # Primary backend
            [{
              name      = v.service_name
              port      = tonumber(v.port)
              weight    = lookup(lookup(v, "canary_deployment", {}), "enabled", false) ? 100 - lookup(lookup(v, "canary_deployment", {}), "canary_weight", 10) : 100
              namespace = lookup(v, "namespace", var.environment.namespace)
            }],
            # Canary backend (if enabled)
            lookup(lookup(v, "canary_deployment", {}), "enabled", false) ? [{
              name      = lookup(lookup(v, "canary_deployment", {}), "canary_service", "")
              port      = tonumber(v.port)
              weight    = lookup(lookup(v, "canary_deployment", {}), "canary_weight", 10)
              namespace = lookup(v, "namespace", var.environment.namespace)
            }] : []
          )
        }]
      }
    } if !lookup(lookup(v, "grpc", {}), "enabled", false)
  }

  # GRPCRoute Resources
  grpcroute_resources = {
    for k, v in local.rulesFiltered : "grpcroute-${lower(var.instance_name)}-${k}" => {
      apiVersion = "gateway.networking.k8s.io/v1alpha2"
      kind       = "GRPCRoute"
      metadata = {
        name      = "${lower(var.instance_name)}-${k}-grpc"
        namespace = var.environment.namespace
      }
      spec = {
        parentRefs = [{
          name        = local.name
          namespace   = var.environment.namespace
          sectionName = "https-${v.domain_key}"
        }]

        hostnames = [v.host]

        rules = [{
          matches = lookup(lookup(v, "grpc", {}), "method_match", null) != null ? [
            for method in lookup(v.grpc, "method_match", []) : {
              method = {
                type    = lookup(method, "type", "Exact")
                service = lookup(method, "service", "")
                method  = lookup(method, "method", "")
              }
            }
          ] : []

          backendRefs = [{
            name      = v.service_name
            port      = tonumber(v.port)
            namespace = lookup(v, "namespace", var.environment.namespace)
          }]
        }]
      }
    } if lookup(lookup(v, "grpc", {}), "enabled", false)
  }

  # Rate Limit Policies
  ratelimit_resources = {
    for k, v in local.rulesFiltered : "ratelimit-${lower(var.instance_name)}-${k}" => {
      apiVersion = "gateway.nginx.org/v1alpha1"
      kind       = "ClientSettingsPolicy"
      metadata = {
        name      = "${lower(var.instance_name)}-${k}-ratelimit"
        namespace = var.environment.namespace
      }
      spec = {
        targetRef = {
          group = "gateway.networking.k8s.io"
          kind  = "HTTPRoute"
          name  = "${lower(var.instance_name)}-${k}"
        }
        rateLimit = {
          rate  = "${lookup(lookup(v, "rate_limiting", {}), "requests_per_second", 100)}r/s"
          burst = lookup(lookup(v, "rate_limiting", {}), "burst", 20)
        }
      }
    } if lookup(lookup(v, "rate_limiting", {}), "enabled", false)
  }

  # IP Whitelist Policies
  ipwhitelist_resources = {
    for k, v in local.rulesFiltered : "ipwhitelist-${lower(var.instance_name)}-${k}" => {
      apiVersion = "gateway.nginx.org/v1alpha1"
      kind       = "ClientSettingsPolicy"
      metadata = {
        name      = "${lower(var.instance_name)}-${k}-ipwhitelist"
        namespace = var.environment.namespace
      }
      spec = {
        targetRef = {
          group = "gateway.networking.k8s.io"
          kind  = "HTTPRoute"
          name  = "${lower(var.instance_name)}-${k}"
        }
        allow = lookup(lookup(v, "ip_whitelist", {}), "allowed_ips", [])
      }
    } if lookup(lookup(v, "ip_whitelist", {}), "enabled", false)
  }

  # Load Balancing Policies (targets Services, not HTTPRoutes)
  loadbalancing_resources = {
    for k, v in local.rulesFiltered : "loadbalancing-${lower(var.instance_name)}-${k}" => {
      apiVersion = "gateway.nginx.org/v1alpha1"
      kind       = "UpstreamSettingsPolicy"
      metadata = {
        name      = "${lower(var.instance_name)}-${k}-lb"
        namespace = var.environment.namespace
      }
      spec = {
        targetRefs = [{
          group = ""
          kind  = "Service"
          name  = v.service_name
        }]
        loadBalancingMethod = lookup(lookup(v, "load_balancing", {}), "algorithm", "round_robin")
      }
    } if lookup(v, "load_balancing", null) != null
  }

  # ServiceMonitor
  servicemonitor_resources = lookup(lookup(lookup(var.instance.spec, "observability", {}), "metrics", {}), "enabled", true) ? {
    "servicemonitor-${local.name}" = {
      apiVersion = "monitoring.coreos.com/v1"
      kind       = "ServiceMonitor"
      metadata = {
        name      = "${local.name}-gateway-metrics"
        namespace = var.environment.namespace
        labels = {
          prometheus = "kube-prometheus"
        }
      }
      spec = {
        selector = {
          matchLabels = {
            "app.kubernetes.io/name"     = "nginx-gateway-fabric"
            "app.kubernetes.io/instance" = local.name
          }
        }
        endpoints = [{
          port     = "metrics"
          interval = "30s"
          path     = "/metrics"
        }]
      }
    }
  } : {}

  # Merge all Gateway API resources
  gateway_api_resources = merge(
    local.http_redirect_resources,
    local.httproute_resources,
    local.grpcroute_resources,
    local.ratelimit_resources,
    local.ipwhitelist_resources,
    local.loadbalancing_resources,
    local.servicemonitor_resources
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

resource "kubernetes_secret" "bootstrap_tls" {
  for_each = local.bootstrap_tls_domains

  metadata {
    name      = "${each.key}-tls-cert"
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

# ServiceAccount for Gateway API CRD installer Job
resource "kubernetes_service_account_v1" "gateway_api_crd_installer" {
  metadata {
    name      = "${local.name}-gateway-api-crd-installer"
    namespace = var.environment.namespace
  }
}

# ClusterRole for Gateway API CRD installer
resource "kubernetes_cluster_role_v1" "gateway_api_crd_installer" {
  metadata {
    name = "${local.name}-gateway-api-crd-installer"
  }

  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
    verbs      = ["get", "list", "create", "update", "patch"]
  }
}

# ClusterRoleBinding for Gateway API CRD installer
resource "kubernetes_cluster_role_binding_v1" "gateway_api_crd_installer" {
  metadata {
    name = "${local.name}-gateway-api-crd-installer"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.gateway_api_crd_installer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.gateway_api_crd_installer.metadata[0].name
    namespace = var.environment.namespace
  }
}

# Job to install Gateway API CRDs
resource "kubernetes_job_v1" "gateway_api_crd_installer" {
  metadata {
    name      = "${local.name}-gateway-api-crd-installer"
    namespace = var.environment.namespace
  }

  spec {
    template {
      metadata {
        labels = {
          app = "gateway-api-crd-installer"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.gateway_api_crd_installer.metadata[0].name
        restart_policy       = "OnFailure"

        container {
          name    = "kubectl"
          image   = "bitnami/kubectl:latest"
          command = ["/bin/sh", "-c"]
          args = [
            "kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml"
          ]
        }
      }
    }

    backoff_limit = 3
  }

  wait_for_completion = true

  timeouts {
    create = "5m"
    update = "5m"
  }

  depends_on = [
    kubernetes_cluster_role_binding_v1.gateway_api_crd_installer
  ]
}

# NGINX Gateway Fabric Helm Chart
resource "helm_release" "nginx_gateway_fabric" {
  name             = local.name
  wait             = lookup(var.instance.spec, "helm_wait", true)
  repository       = lookup(var.instance.spec, "helm_chart_version", null) != null ? "oci://ghcr.io/nginx/charts" : null
  chart            = lookup(var.instance.spec, "helm_chart_version", null) != null ? "nginx-gateway-fabric" : "${path.module}/charts/nginx-gateway-fabric-2.3.0.tgz"
  version          = lookup(var.instance.spec, "helm_chart_version", null)
  namespace        = var.environment.namespace
  max_history      = 10
  skip_crds        = false
  create_namespace = false
  timeout          = 600

  values = [
    yamlencode({
      nginxGateway = {
        # Configure the GatewayClass name
        gatewayClassName = local.gateway_class_name

        image = {
          pullPolicy = "IfNotPresent"
        }
        imagePullSecrets = lookup(var.inputs, "artifactories", null) != null ? var.inputs.artifactories.attributes.registry_secrets_list : []

        resources = {
          requests = {
            cpu    = lookup(lookup(lookup(var.instance.spec, "resources", {}), "requests", {}), "cpu", "100m")
            memory = lookup(lookup(lookup(var.instance.spec, "resources", {}), "requests", {}), "memory", "200Mi")
          }
          limits = lookup(lookup(var.instance.spec, "resources", {}), "limits", null) != null ? {
            cpu    = lookup(lookup(var.instance.spec, "resources", {}).limits, "cpu", null)
            memory = lookup(lookup(var.instance.spec, "resources", {}).limits, "memory", null)
          } : null
        }

        tolerations  = local.ingress_tolerations
        nodeSelector = local.nodepool_labels

        metrics = {
          enabled = lookup(lookup(lookup(var.instance.spec, "observability", {}), "metrics", {}), "enabled", true)
          port    = lookup(lookup(lookup(var.instance.spec, "observability", {}), "metrics", {}), "port", 9113)
        }
      }

      # NGINX data plane configuration (NginxProxy)
      nginx = {
        config = {
          clientMaxBodySize   = lookup(lookup(var.instance.spec, "nginx_config", {}), "body_size_limit", "1m")
          proxyConnectTimeout = lookup(lookup(lookup(var.instance.spec, "nginx_config", {}), "proxy_timeouts", {}), "connect", "60s")
          proxySendTimeout    = lookup(lookup(lookup(var.instance.spec, "nginx_config", {}), "proxy_timeouts", {}), "send", "60s")
          proxyReadTimeout    = lookup(lookup(lookup(var.instance.spec, "nginx_config", {}), "proxy_timeouts", {}), "read", "60s")
          # Enable Proxy Protocol to get real client IP with externalTrafficPolicy: Cluster
          rewriteClientIP = local.cloud_provider == "AWS" ? {
            mode = "ProxyProtocol"
            trustedAddresses = [
              {
                type  = "CIDR"
                value = "0.0.0.0/0"
              }
            ]
          } : null
        }
        service = {
          type                  = "LoadBalancer"
          externalTrafficPolicy = "Cluster"
          patches = length(local.service_annotations) > 0 ? [
            {
              type = "StrategicMerge"
              value = {
                metadata = {
                  annotations = local.service_annotations
                }
              }
            }
          ] : []
        }
      }

      # Gateway configuration
      gateways = [{
        name      = local.name
        namespace = var.environment.namespace
        labels = {
          gateway = "facets"
        }
        annotations = {
          "cert-manager.io/cluster-issuer" = local.disable_endpoint_validation ? local.cluster_issuer_dns : local.cluster_issuer_gateway_http
          "cert-manager.io/renew-before"   = lookup(var.instance.spec, "renew_cert_before", "720h")
        }
        spec = {
          gatewayClassName = local.gateway_class_name
          listeners = concat(
            # HTTP Listener
            [{
              name     = "http"
              protocol = "HTTP"
              port     = 80
              allowedRoutes = {
                namespaces = {
                  from = "Same"
                }
              }
            }],
            # HTTPS Listeners per domain
            [for domain_key, domain in local.domains : {
              name     = "https-${domain_key}"
              protocol = "HTTPS"
              port     = 443
              hostname = domain.domain
              tls = {
                mode = "Terminate"
                certificateRefs = [{
                  kind = "Secret"
                  # DNS-01: use certificate_reference (fallback to dns_validation_secret_name)
                  # HTTP-01: always use auto-generated name, ignore certificate_reference (same as nginx_k8s_native)
                  name = local.disable_endpoint_validation ? lookup(domain, "certificate_reference", local.dns_validation_secret_name) : "${domain_key}-tls-cert"
                }]
              }
              allowedRoutes = {
                namespaces = {
                  from = "Same"
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
    kubernetes_job_v1.gateway_api_crd_installer,
    kubernetes_secret.bootstrap_tls
  ]
}

# Gateway API HTTP-01 ClusterIssuer - bundled here as it requires parentRefs to the Gateway
# See: https://github.com/cert-manager/cert-manager/issues/7890
module "cluster-issuer-gateway-http01" {
  count           = local.disable_endpoint_validation ? 0 : 1
  depends_on      = [helm_release.nginx_gateway_fabric]
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = local.cluster_issuer_gateway_http
  namespace       = var.environment.namespace
  advanced_config = {}

  data = {
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
                    name      = local.name
                    namespace = var.environment.namespace
                    kind      = "Gateway"
                  }
                ]
              }
            }
          },
        ]
      }
    }
  }
}

# Deploy all Gateway API resources using facets-utility-modules
module "gateway_api_resources" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resources"

  name            = "${local.name}-gateway-api"
  release_name    = "${local.name}-gateway-api"
  namespace       = var.environment.namespace
  resources_data  = local.gateway_api_resources
  advanced_config = {}

  depends_on = [helm_release.nginx_gateway_fabric]
}

# Basic Authentication
# NOTE: Basic auth is not natively supported in NGINX Gateway Fabric.
# Unlike ingress-nginx, NGF doesn't have auth annotations.
# Implementation would require SnippetsFilter + volume mounts which is complex and fragile.
# TODO: Implement when NGF adds native policy support or use app-level auth.
#
# resource "random_string" "basic_auth_password" {
#   count   = lookup(var.instance.spec, "basic_auth", false) ? 1 : 0
#   length  = 16
#   special = true
# }
#
# resource "kubernetes_secret" "basic_auth" {
#   count = lookup(var.instance.spec, "basic_auth", false) ? 1 : 0
#
#   metadata {
#     name      = "${local.name}-basic-auth"
#     namespace = var.environment.namespace
#   }
#
#   data = {
#     username = "${var.instance_name}-user"
#     password = random_string.basic_auth_password[0].result
#   }
#
#   type = "Opaque"
# }

# Load Balancer Service Discovery
# Note: The LoadBalancer service is created by NGINX Gateway Fabric controller
# when it processes the Gateway resource from the Helm chart
data "kubernetes_service" "gateway_lb" {
  depends_on = [
    helm_release.nginx_gateway_fabric
  ]
  metadata {
    name      = "${local.name}-nginx-fabric"
    namespace = var.environment.namespace
  }
}

# Route53 DNS Records (AWS)
resource "aws_route53_record" "cluster-base-domain" {
  count = local.tenant_provider == "aws" && !lookup(var.instance.spec, "disable_base_domain", false) ? 1 : 0
  depends_on = [
    helm_release.nginx_gateway_fabric,
    data.kubernetes_service.gateway_lb
  ]
  zone_id  = var.cc_metadata.tenant_base_domain_id
  name     = local.base_domain
  type     = local.record_type
  ttl      = "300"
  records  = [local.lb_record_value]
  provider = "aws3tooling"
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
  zone_id  = var.cc_metadata.tenant_base_domain_id
  name     = local.base_subdomain
  type     = local.record_type
  ttl      = "300"
  records  = [local.lb_record_value]
  provider = "aws3tooling"
  lifecycle {
    prevent_destroy = true
  }
}
