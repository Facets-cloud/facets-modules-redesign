variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      container = object({
        image   = string
        port    = string
        command = optional(list(string))
        args    = optional(list(string))
      })

      env = optional(map(string), {})
      secrets = optional(map(object({
        secret_name = string
        version     = optional(string, "latest")
      })), {})

      gcs_volumes = optional(map(object({
        bucket     = string
        mount_path = string
        read_only  = optional(bool, false)
      })), {})

      resources = optional(object({
        cpu               = optional(string, "1000m")
        memory            = optional(string, "512Mi")
        startup_cpu_boost = optional(bool, false)
        cpu_idle          = optional(bool)
        }), {
        cpu               = "1000m"
        memory            = "512Mi"
        startup_cpu_boost = false
      })

      scaling = optional(object({
        min_instances = optional(number, 0)
        max_instances = optional(number, 10)
        concurrency   = optional(number, 80)
        }), {
        min_instances = 0
        max_instances = 10
        concurrency   = 80
      })

      timeout = optional(string, "300")
      ingress = optional(string, "all")

      auth = optional(object({
        allow_unauthenticated = optional(bool, false)
        }), {
        allow_unauthenticated = false
      })

      vpc_access = optional(object({
        enabled   = optional(bool, false)
        connector = optional(string)
        egress    = optional(string, "private-ranges-only")
        }), {
        enabled = false
        egress  = "private-ranges-only"
      })

      service_account = optional(string)

      annotations = optional(map(string), {})
      labels      = optional(map(string), {})

      # Deletion protection - defaults to true for safety
      deletion_protection = optional(bool, true)

      health_checks = optional(object({
        startup_probe = optional(object({
          enabled           = optional(bool, false)
          path              = optional(string, "/health/startup")
          initial_delay     = optional(number, 0)
          timeout           = optional(number, 1)
          period            = optional(number, 10)
          failure_threshold = optional(number, 3)
          }), {
          enabled = false
        })
        liveness_probe = optional(object({
          enabled           = optional(bool, false)
          path              = optional(string, "/health/live")
          initial_delay     = optional(number, 0)
          timeout           = optional(number, 1)
          period            = optional(number, 10)
          failure_threshold = optional(number, 3)
          }), {
          enabled = false
        })
        }), {
        startup_probe  = { enabled = false }
        liveness_probe = { enabled = false }
      })
    })
  })

  description = "Cloud Run service instance configuration"
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
    network = optional(object({
      attributes = optional(object({
        vpc_id   = optional(string)
        vpc_name = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    }))
  })
  description = "Dependencies from other modules"
}
