variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      machine = object({
        machine_type = string
        zone         = optional(string)
      })

      boot_disk = object({
        image   = string
        size_gb = optional(number, 20)
        type    = optional(string, "pd-balanced")
      })

      scaling = optional(object({
        min_instances   = optional(number, 1)
        max_instances   = optional(number, 3)
        cpu_target      = optional(number, 0.6)
        cooldown_period = optional(number, 60)
        }), {
        min_instances   = 1
        max_instances   = 3
        cpu_target      = 0.6
        cooldown_period = 60
      })

      user_data = optional(string, "")

      env = optional(map(string), {})

      network = optional(object({
        assign_external_ip = optional(bool, true)
        network_tags       = optional(list(string), [])
        }), {
        assign_external_ip = true
        network_tags       = []
      })

      cloud_permissions = optional(object({
        gcp = optional(object({
          roles = optional(map(object({
            role = string
            condition = optional(object({
              title       = string
              expression  = string
              description = optional(string)
            }))
          })), {})
        }), { roles = {} })
      }), { gcp = { roles = {} } })

      labels = optional(map(string), {})

      deletion_protection = optional(bool, false)

      # When true, the MIG preserves the boot disk across instance recreation
      stateful = optional(bool, false)
    })
  })

  description = "GCP VM service instance configuration"
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
    gcp_provider = object({
      attributes = object({
        project_id = string
        region     = string
      })
      interfaces = optional(object({}), {})
    })
    network = object({
      attributes = optional(object({
        vpc_id            = optional(string)
        vpc_name          = optional(string)
        vpc_self_link     = optional(string)
        private_subnet_id = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
  description = "Dependencies from other modules"
}
