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
        read_only  = optional(bool, true)
      })), {})

      resources = object({
        cpu               = string
        memory            = string
        cpu_throttling    = optional(bool, false)
        startup_cpu_boost = optional(bool, false)
      })

      gpu = object({
        enabled          = bool
        type             = optional(string, "nvidia-l4")
        zonal_redundancy = optional(bool, false)
      })

      scaling = object({
        min_instances = number
        max_instances = number
        concurrency   = number
      })

      timeout = optional(string, "600")
      ingress = optional(string, "")

      auth = optional(object({
        allow_unauthenticated = optional(bool, false)
        }), {
        allow_unauthenticated = false
      })

      vpc_access = optional(object({
        enabled = optional(bool, false)
        egress  = optional(string, "private-ranges-only")
        }), {
        enabled = false
        egress  = "private-ranges-only"
      })

      health_checks = optional(object({
        startup_probe = optional(object({
          enabled           = optional(bool, true)
          type              = optional(string, "tcp")
          port              = optional(string, "8080")
          path              = optional(string, "/health/startup")
          initial_delay     = optional(number, 0)
          timeout           = optional(number, 30)
          period            = optional(number, 60)
          failure_threshold = optional(number, 10)
          }), {
          enabled = true
        })
        liveness_probe = optional(object({
          enabled           = optional(bool, false)
          type              = optional(string, "http")
          port              = optional(string, "8080")
          path              = optional(string, "/health/live")
          initial_delay     = optional(number, 0)
          timeout           = optional(number, 1)
          period            = optional(number, 10)
          failure_threshold = optional(number, 3)
          }), {
          enabled = false
        })
        }), {
        startup_probe  = { enabled = true }
        liveness_probe = { enabled = false }
      })

      service_account = optional(string)
      annotations     = optional(map(string), {})
      labels          = optional(map(string), {})
    })
  })

  description = "Cloud Run GPU service instance configuration"

  validation {
    condition     = contains(["20", "22", "24", "26", "30"], var.instance.spec.resources.cpu)
    error_message = "CPU must be one of: 20, 22, 24, 26, 30."
  }

  validation {
    condition     = contains(["80Gi", "96Gi", "104Gi", "128Gi"], var.instance.spec.resources.memory)
    error_message = "Memory must be one of: 80Gi, 96Gi, 104Gi, 128Gi."
  }

  validation {
    condition     = !var.instance.spec.gpu.enabled || contains(["nvidia-l4", "nvidia-rtx-pro-6000"], var.instance.spec.gpu.type)
    error_message = "GPU type must be nvidia-l4 or nvidia-rtx-pro-6000."
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
    gcp_provider = object({
      attributes = object({
        project_id = string
        region     = string
      })
    })
    network = optional(object({
      attributes = object({
        vpc_id             = string
        vpc_connector_id   = optional(string)
        vpc_connector_name = optional(string)
      })
    }))
  })
  description = "Dependencies from other modules"
}
