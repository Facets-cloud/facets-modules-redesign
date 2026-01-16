variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      namespace         = optional(string, "traefik")
      service_type      = optional(string, "LoadBalancer")
      replicas          = optional(number, 2)
      private           = optional(bool, false)
      basic_auth        = optional(bool, false)
      basic_auth_secret = optional(string)
      grpc              = optional(bool, false)

      domains = map(object({
        domain = string
        alias  = optional(string)
        custom_tls = optional(object({
          enabled     = optional(bool, false)
          certificate = optional(string)
          private_key = optional(string)
        }), {})
      }))

      rules = map(object({
        disable                     = optional(bool, false)
        domain_prefix               = optional(string, "*")
        service_name                = string
        namespace                   = optional(string)
        port                        = optional(string, "80")
        path                        = optional(string, "/")
        enable_rewrite_target       = optional(bool, false)
        enable_header_based_routing = optional(bool, false)

        header_routing_rules = optional(map(object({
          header_name  = string
          header_value = string
          match_type   = optional(string, "exact")
        })), {})

        session_affinity = optional(object({
          session_cookie_name    = optional(string, "route")
          session_cookie_expires = optional(number, 3600)
          session_cookie_max_age = optional(number, 3600)
        }), {})

        cors = optional(object({
          enable          = optional(bool, false)
          allowed_origins = optional(list(string), [])
          allowed_methods = optional(list(string), [])
        }), {})

        annotations = optional(map(string), {})
      }))

      force_ssl_redirection = optional(bool, true)
      ingress_chart_version = optional(string, "38.0.2")
      disable_base_domain   = optional(bool, false)

      certificate = optional(object({
        use_cert_manager = optional(bool, false)
        issuer_name      = optional(string, "letsencrypt-prod")
        issuer_kind      = optional(string, "ClusterIssuer")
      }), {})

      custom_error_pages = optional(map(object({
        error_code   = string
        page_content = string
      })), {})

      pdb = optional(object({
        maxUnavailable = optional(string, "1")
        minAvailable   = optional(string)
      }), {})

      ip_whitelist = optional(object({
        enabled         = optional(bool, false)
        protected_paths = optional(list(string), ["actuator", "prometheus", "/metrics"])
        allowed_ips     = optional(list(string), [])
      }), {})

      security_headers = optional(object({
        x_frame_options         = optional(string, "SAMEORIGIN")
        content_security_policy = optional(string)
        referrer_policy         = optional(string, "same-origin")
        x_content_type_options  = optional(string, "nosniff")
        x_xss_protection        = optional(string, "1; mode=block")
      }), {})

      global_header_routing = optional(object({
        enabled = optional(bool, false)
        rules = optional(map(object({
          header_name  = string
          header_value = string
          match_type   = optional(string, "exact")
        })), {})
      }), {})

      resources = optional(object({
        requests = optional(object({
          cpu    = optional(string, "100m")
          memory = optional(string, "128Mi")
        }), {})
        limits = optional(object({
          cpu    = optional(string, "500m")
          memory = optional(string, "512Mi")
        }), {})
      }), {})

      global_annotations = optional(map(string), {})
    })
  })

  validation {
    condition     = var.instance.spec.replicas >= 1 && var.instance.spec.replicas <= 10
    error_message = "Replicas must be between 1 and 10."
  }

  validation {
    condition     = contains(["LoadBalancer", "ClusterIP", "NodePort"], var.instance.spec.service_type)
    error_message = "Service type must be LoadBalancer, ClusterIP, or NodePort."
  }
}

variable "instance_name" {
  type        = string
  description = "Unique architectural name from blueprint"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
  description = "Environment configuration"
}

variable "inputs" {
  type = object({
    kubernetes_cluster = object({
      attributes = object({
        cluster_endpoint       = string
        cluster_ca_certificate = string
        cluster_name           = optional(string)
      })
    })
    traefik_crds = object({
      attributes = object({
        crds_installed = string
      })
    })
    gateway_api_crds = object({
      attributes = object({
        crds_installed      = string
        gateway_api_version = string
      })
    })
  })
  description = "Input dependencies from other modules"
}

variable "cc_metadata" {
  type        = any
  description = "Tenant metadata including Route53 zone ID (tenant_base_domain_id)"
  default     = {}
}
