variable "instance" {
  description = "Vultr load balancer fronting compute instances"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      region              = optional(string)
      balancing_algorithm = optional(string, "roundrobin")
      nodes               = optional(number, 1)
      ssl_redirect        = optional(bool, false)
      proxy_protocol      = optional(bool, false)
      forwarding_rules = map(object({
        frontend_protocol = string
        frontend_port     = string
        backend_protocol  = string
        backend_port      = string
      }))
      health_check = optional(object({
        protocol            = optional(string, "tcp")
        port                = optional(string, "80")
        path                = optional(string, "/")
        check_interval      = optional(number, 15)
        response_timeout    = optional(number, 5)
        unhealthy_threshold = optional(number, 5)
        healthy_threshold   = optional(number, 5)
      }), {})
    })
  })

  validation {
    condition     = contains(["roundrobin", "leastconn"], var.instance.spec.balancing_algorithm)
    error_message = "balancing_algorithm must be roundrobin or leastconn."
  }
}

variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    vultr_cloud_account = object({
      attributes = object({
        api_key = string
        region  = string
      })
    })
    compute = object({
      attributes = object({
        instance_ids = list(string)
        region       = optional(string)
      })
    })
    network = optional(object({
      attributes = object({
        vpc_id = string
      })
    }))
  })
}
