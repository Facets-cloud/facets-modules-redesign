variable "instance" {
  description = "The service resource instance containing the complete configuration"
  type = object({
    # Module identification
    kind     = string
    flavor   = string
    version  = string
    disabled = optional(bool, false)

    # Main specification from facets.yaml
    spec = object({
      # Workload type: application, cronjob, job, or statefulset
      type = optional(string, "application")

      # Restart policy (for application/statefulset)
      restart_policy = optional(string)

      # Pod distribution settings
      enable_host_anti_affinity = optional(bool, false)

      # Runtime configuration
      runtime = object({
        # Container command and args
        command = optional(list(string), [])
        args    = optional(list(string), [])

        # Resource sizing
        size = object({
          cpu          = string
          memory       = string
          cpu_limit    = optional(string)
          memory_limit = optional(string)
        })

        # Port mappings
        ports = optional(map(object({
          port         = string
          service_port = optional(string)
          protocol     = string
        })), {})

        # Health checks (optional)
        health_checks = optional(object({
          readiness_check_type = string
          liveness_check_type  = string
        }))

        # Autoscaling (optional)
        autoscaling = optional(object({
          min           = number
          max           = number
          scaling_on    = string
          cpu_threshold = optional(string)
          ram_threshold = optional(string)
        }))

        # Metrics configuration (optional)
        metrics = optional(map(object({
          path      = string
          port_name = string
        })), {})

        # Volume mounts
        volumes = optional(object({
          config_maps = optional(map(object({
            name       = string
            mount_path = string
            sub_path   = optional(string)
          })), {})
          secrets = optional(map(object({
            name       = string
            mount_path = string
            sub_path   = optional(string)
          })), {})
          pvc = optional(map(object({
            claim_name = string
            mount_path = string
            sub_path   = optional(string)
          })), {})
          host_path = optional(map(object({
            mount_path = string
            sub_path   = optional(string)
          })), {})
        }), {})
      })

      # Release configuration
      release = optional(object({
        image             = optional(string)
        image_pull_policy = optional(string, "IfNotPresent")
      }), {})

      # Environment variables
      env = optional(map(string), {})

      # Init containers
      init_containers = optional(map(object({
        image       = string
        pull_policy = string
        env         = optional(map(string), {})
        runtime = object({
          command = optional(list(string), [])
          args    = optional(list(string), [])
          size = object({
            cpu          = string
            memory       = string
            cpu_limit    = optional(string)
            memory_limit = optional(string)
          })
          volumes = optional(any, {})
        })
      })), {})

      # Sidecar containers
      sidecars = optional(map(object({
        image       = string
        pull_policy = string
        env         = optional(map(string), {})
        runtime = object({
          command = optional(list(string), [])
          args    = optional(list(string), [])
          size = object({
            cpu          = string
            memory       = string
            cpu_limit    = optional(string)
            memory_limit = optional(string)
          })
          ports = optional(map(object({
            port = string
          })), {})
          health_checks = optional(any)
          volumes       = optional(any, {})
        })
      })), {})

      # Enable actions (deployment/statefulset actions)
      enable_actions = optional(bool, true)
    })

    # Advanced configuration (no AWS-specific block)
    advanced = optional(object({
      common = optional(object({
        app_chart = optional(object({
          values = optional(any, {})
        }), {})
      }), {})
    }), {})
  })
}

variable "inputs" {
  description = "Input dependencies from other resources defined in facets.yaml inputs section"
  type = object({
    # Required: Kubernetes cluster details (generic)
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider         = optional(string)
        cluster_endpoint       = optional(string)
        cluster_ca_certificate = optional(string)
        cluster_name           = optional(string)
        cluster_location       = optional(string)
        cluster_id             = optional(string)
      }))
    })

    # Required: OVH Kubernetes node pool details
    kubernetes_node_pool_details = object({
      attributes = optional(object({
        node_pool_name = optional(string)
        taints = optional(list(object({
          key    = string
          value  = string
          effect = string
        })), [])
        node_selector = optional(map(string), {})
        flavor_name   = optional(string)
      }))
      interfaces = optional(object({}))
    })

    # Optional: Container registry access
    artifactories = optional(object({
      attributes = optional(object({
        registry_secret_objects = optional(map(list(object({
          name = string
        }))), {})
        registry_secrets_list = optional(list(object({
          name = string
        })), [])
      }))
      interfaces = optional(object({}))
    }))

    # Optional: Vertical Pod Autoscaler
    vpa_details = optional(object({
      attributes = optional(object({
        helm_release_id              = optional(string)
        helm_release_name            = optional(string)
        namespace                    = optional(string)
        version                      = optional(string)
        recommender_enabled          = optional(bool)
        updater_enabled              = optional(bool)
        admission_controller_enabled = optional(bool)
      }))
      interfaces = optional(object({}))
    }))
  })
}

variable "instance_name" {
  description = "The name of the service instance (from metadata.name or filename)"
  type        = string
  default     = "test_instance"
}

variable "environment" {
  description = "Environment configuration including namespace and other environment-specific settings"
  type = object({
    name                         = optional(string)
    unique_name                  = string
    namespace                    = string
    cloud_tags                   = optional(map(string), {})
    default_tolerations          = optional(list(any), [])
    global_variables             = optional(map(string), {})
    common_environment_variables = optional(map(string), {})
    deployment_id                = optional(string, "")
    secrets                      = optional(map(string), {})
  })
}
