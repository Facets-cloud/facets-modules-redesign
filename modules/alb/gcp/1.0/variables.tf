variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      domains = map(object({
        domain          = string
        default_service = string
        paths = optional(map(object({
          service   = string
          path_type = optional(string, "PREFIX")
        })), {})
        certificate = optional(object({
          mode               = optional(string, "auto")
          managed_cert_name  = optional(string)
          existing_cert_name = optional(string)
        }))
      }))
      global_config = optional(object({
        enable_cdn = optional(bool, false)
        cdn_policy = optional(object({
          cache_mode  = optional(string, "USE_ORIGIN_HEADERS")
          default_ttl = optional(number, 3600)
          max_ttl     = optional(number, 86400)
        }))
        enable_iap = optional(bool, false)
        iap_config = optional(object({
          oauth2_client_id     = string
          oauth2_client_secret = string
        }))
        security_policy = optional(string)
        custom_headers  = optional(map(string), {})
        timeout_sec     = optional(number, 30)
        }), {
        enable_cdn  = false
        enable_iap  = false
        timeout_sec = 30
      })
      advanced = optional(object({
        ip_address_name             = optional(string)
        enable_http                 = optional(bool, true)
        http_redirect               = optional(bool, true)
        session_affinity            = optional(string, "NONE")
        connection_draining_timeout = optional(number, 300)
        }), {
        enable_http                 = true
        http_redirect               = true
        session_affinity            = "NONE"
        connection_draining_timeout = 300
      })
    })
  })

  validation {
    condition = alltrue([
      for key, config in var.instance.spec.domains :
      can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$", config.domain))
    ])
    error_message = "Domain names must be valid lowercase DNS names."
  }

  validation {
    condition = alltrue([
      for domain, config in var.instance.spec.domains :
      alltrue([
        for path, path_config in lookup(config, "paths", {}) :
        startswith(path, "/")
      ])
    ])
    error_message = "All paths must start with '/'."
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
}

variable "inputs" {
  type = object({
    gcp_cloud_account = object({
      attributes = object({
        project_id = string
        region     = string
      })
    })
    network = optional(object({
      attributes = object({
        vpc_name      = string
        vpc_id        = string
        vpc_self_link = string
      })
    }))
  })
}
