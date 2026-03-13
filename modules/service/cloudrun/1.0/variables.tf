variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      release = object({
        image             = string
        image_pull_policy = optional(string, "IfNotPresent")
      })

      runtime = object({
        port    = string
        command = optional(list(string))
        args    = optional(list(string))

        size = optional(object({
          cpu               = optional(string, "1000m")
          memory            = optional(string, "512Mi")
          startup_cpu_boost = optional(bool, false)
          cpu_idle          = optional(bool)
          }), {
          cpu               = "1000m"
          memory            = "512Mi"
          startup_cpu_boost = false
        })

        autoscaling = optional(object({
          enabled     = optional(bool, true)
          min         = optional(number, 0)
          max         = optional(number, 10)
          concurrency = optional(number, 80)
          }), {
          enabled     = true
          min         = 0
          max         = 10
          concurrency = 80
        })

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

      env = optional(map(string), {})

      gcs_volumes = optional(map(object({
        bucket     = string
        mount_path = string
        read_only  = optional(bool, false)
      })), {})

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

      annotations = optional(map(string), {})
      labels      = optional(map(string), {})
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
