variable "instance" {
  description = "Vultr cloud compute instances (count-scaled)"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      region = optional(string)
      sizing = object({
        plan  = string
        count = number
      })
      image = object({
        os_id = number
      })
      networking = optional(object({
        attach_vpc  = optional(bool, true)
        enable_ipv6 = optional(bool, false)
      }), {})
      access = optional(object({
        ssh_public_keys = optional(list(string), [])
        startup_script  = optional(string, "")
      }), {})
      firewall = optional(object({
        manage = optional(bool, false)
        open_ports = optional(map(object({
          port     = string
          protocol = optional(string, "tcp")
          source   = optional(string, "0.0.0.0/0")
        })), {})
      }), {})
    })
  })

  validation {
    condition     = var.instance.spec.sizing.count >= 1 && var.instance.spec.sizing.count <= 20
    error_message = "count must be between 1 and 20."
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
    network = optional(object({
      attributes = object({
        vpc_id = string
      })
    }))
  })
}
