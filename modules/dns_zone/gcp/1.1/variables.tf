variable "instance" {
  description = "Instance configuration"
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
    spec = object({
      zone_name           = string
      dns_name            = string
      description         = optional(string, "")
      project_id_override = optional(string, "")
      existing_zone_id    = optional(string, "")
      visibility          = optional(string, "public")
      dnssec              = optional(string, "off")
      network_self_links  = optional(list(string), [])
      records = optional(map(object({
        name   = string
        type   = string
        ttl    = optional(number, 300)
        value  = optional(string, "")
        values = optional(list(string), [])
      })), {})
    })
  })
}

variable "instance_name" {
  description = "Name of the instance"
  type        = string
  default     = "test_instance"
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    name         = optional(string, "default")
    unique_name  = optional(string, "default")
    namespace    = optional(string, "default")
    cloud_tags   = optional(map(string), {})
    cluster_code = optional(string, "")
  })
  default = {}
}

variable "inputs" {
  description = "Input references from other modules"
  type = object({
    cloud_account = object({
      attributes = optional(object({
        credentials = optional(string)
        project_id  = optional(string)
        region      = optional(string)
        secrets     = optional(list(string), [])
      }), {})
      interfaces = optional(object({}), {})
    })
    network = object({
      attributes = optional(object({
        project_id         = optional(string)
        region             = optional(string)
        vpc_id             = optional(string)
        vpc_name           = optional(string)
        vpc_self_link      = optional(string)
        private_subnet_ids = optional(list(string), [])
        public_subnet_ids  = optional(list(string), [])
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}
