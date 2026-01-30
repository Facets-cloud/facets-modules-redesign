variable "instance" {
  description = "The service resource instance containing the complete configuration"
  type = object({
    # Module identification
    kind     = string
    flavor   = string
    version  = string
    disabled = optional(bool, false)

    # Metadata for the service
    metadata = optional(object({
      namespace   = optional(string)
      labels      = optional(map(string), {})
      annotations = optional(map(string), {})
    }), {})

    # Main specification from facets.yaml
    spec = object({
      # Workload type: application, cronjob, job, or statefulset
      type = optional(string, "application")

      # Restart policy (for application/statefulset)
      restart_policy = optional(string)

      # Pod distribution (high-level toggle retained; detailed mapping lives in locals)
      enable_host_anti_affinity = optional(bool, false)

      # Cloud permissions (Azure roles for AAD pod identity and RBAC)
      cloud_permissions = optional(object({
        azure = optional(object({
          roles = optional(map(object({
            role      = string
            condition = optional(any)
          })), {})
        }), {})
      }), {})

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

        strategy = optional(object({
          type            = string
          max_available   = optional(string)
          max_unavailable = optional(string)
        }))

        disruption_policy = optional(object({
          min_available   = optional(string)
          max_unavailable = optional(string)
        }))
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

    # Advanced/Azure-specific configuration
    advanced = optional(object({
      azure = optional(object({
        iam = optional(map(object({
          role      = string
          condition = optional(any)
        })), {})
      }), {})
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
    # Required: Azure Cloud Account
    cloud_account = object({
      attributes = optional(object({
        subscription_id = optional(string)
        tenant_id       = optional(string)
        client_id       = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })

    # Required: Kubernetes cluster details
    kubernetes_details = object({
      attributes = optional(any, {})
      interfaces = optional(any, {})
    })

    # Required: Node pool details
    kubernetes_node_pool_details = object({
      attributes = optional(object({
        cluster_id     = optional(string)
        disk_size      = optional(number)
        node_count     = optional(number)
        node_pool_name = optional(string)
        node_selector  = optional(map(string), {})
        taints         = optional(list(string), [])
      }), {})
      interfaces = optional(object({}), {})
    })

    # Required: Network details
    network_details = object({
      attributes = optional(object({
        availability_zones   = optional(list(string), [])
        private_subnet_ids   = optional(list(string), [])
        private_subnet_cidrs = optional(list(string), [])
        public_subnet_ids    = optional(list(string), [])
        public_subnet_cidrs  = optional(list(string), [])
        vnet_id              = optional(string)
        vnet_name            = optional(string)
        vnet_cidr_block      = optional(string)
        resource_group_name  = optional(string)
        resource_group_id    = optional(string)
        region               = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })

    # Optional: Container registry access
    artifactories = optional(object({
      attributes = optional(object({
        registry_secrets_list = optional(list(any), [])
      }), {})
      interfaces = optional(object({}), {})
    }))

    # Optional: Vertical Pod Autoscaler
    vpa_details = optional(object({
      attributes = optional(object({
        helm_release_id = optional(string, "")
      }), {})
      interfaces = optional(object({}), {})
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
    name        = optional(string)
    unique_name = string
    namespace   = string
    cloud_tags  = optional(map(string), {})
  })
  default = {
    name        = "default"
    unique_name = "default-unique"
    namespace   = "default"
    cloud_tags  = {}
  }
}
