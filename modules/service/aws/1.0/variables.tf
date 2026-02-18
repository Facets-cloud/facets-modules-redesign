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
      pod_distribution_enabled  = optional(bool, false)
      pod_distribution          = optional(map(any), {})

      # Cloud permissions (AWS IRSA/IAM)
      cloud_permissions = optional(object({
        aws = optional(object({
          enable_irsa  = optional(bool)
          iam_policies = optional(map(object({ arn = string })), {})
        }), {})
      }), {})

      # Cronjob configuration (visible when spec.type = cronjob)
      cronjob = optional(object({
        schedule           = string
        suspend            = bool
        concurrency_policy = string
      }))

      # Job configuration (visible when spec.type = job or cronjob)
      job = optional(object({
        retry = string
      }))

      # Persistent volume claims (visible when spec.type = statefulset)
      persistent_volume_claims = optional(map(object({
        access_mode  = string
        storage_size = string
        path         = string
      })), {})

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

        # Health checks (optional, typed as any to support all check type fields)
        health_checks = optional(any)

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
        image                   = string
        pull_policy             = string
        env                     = optional(map(string), {})
        additional_k8s_env      = optional(any)
        additional_k8s_env_from = optional(any)
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
        image                   = string
        pull_policy             = string
        env                     = optional(map(string), {})
        additional_k8s_env      = optional(any)
        additional_k8s_env_from = optional(any)
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

    # Advanced/AWS-specific configuration
    advanced = optional(object({
      aws = optional(object({
        enable_irsa = optional(bool)
        iam         = optional(map(object({ arn = string })), {})
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
    # Required: AWS Cloud Account
    cloud_account = object({
      attributes = optional(object({
        aws_iam_role = optional(string)
        aws_region   = optional(string)
        external_id  = optional(string)
        session_name = optional(string)
      }))
      interfaces = optional(object({}))
    })

    # Required: Kubernetes cluster details (EKS)
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider         = optional(string)
        cluster_arn            = optional(string)
        cluster_ca_certificate = optional(string)
        cluster_endpoint       = optional(string)
        cluster_id             = optional(string)
        cluster_name           = optional(string)
        cluster_location       = optional(string)
        cluster_version        = optional(string)
        node_iam_role_arn      = optional(string)
        node_iam_role_name     = optional(string)
        node_security_group_id = optional(string)
        oidc_issuer_url        = optional(string)
        oidc_provider          = optional(string)
        oidc_provider_arn      = optional(string)
        secrets                = optional(list(string))
        kubernetes_provider_exec = optional(object({
          api_version = optional(string)
          args        = optional(list(string))
          command     = optional(string)
        }))
      }))
    })

    # Required: Kubernetes node pool details (Karpenter)
    kubernetes_node_pool_details = object({
      attributes = optional(object({
        node_class_name = optional(string)
        node_pool_name  = optional(string)
        taints          = optional(string)
        node_selector   = optional(string)
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
