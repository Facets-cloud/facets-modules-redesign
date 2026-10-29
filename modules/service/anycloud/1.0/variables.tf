variable "instance" {
  description = "The service resource instance containing the complete configuration"
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
    spec = object({
      namespace = optional(string)
      cronjob = optional(object({
        concurrency_policy = string
        schedule           = string
        suspend            = bool
      }))
      enable_host_anti_affinity = optional(bool)
      env                       = optional(map(string), {})
      # MUST be declared: spec is a closed object type, so an undeclared field is silently dropped.
      cloud_permissions = optional(object({
        aws = optional(object({
          enable_irsa        = optional(bool, false)
          inline_policy_json = optional(string, "")
          iam_policies = optional(map(object({
            arn = string
          })), {})
        }), {})
        gcp = optional(object({
          enable_wi = optional(bool, false)
          roles = optional(map(object({
            role = string
          })), {})
        }), {})
      }), {})
      init_containers = optional(map(any))
      job = optional(object({
        retry = string
      }))
      persistent_volume_claims = optional(map(any))
      pod_distribution         = optional(map(any))
      pod_distribution_enabled = optional(bool)
      release = optional(object({
        disruption_policy = optional(object({
          max_unavailable = optional(string)
          min_available   = optional(string)
        }))
        image             = optional(string)
        image_pull_policy = optional(string)
        strategy = optional(object({
          max_available   = optional(string)
          max_unavailable = optional(string)
          type            = optional(string)
        }))
      }))
      restart_policy = optional(string)
      runtime = object({
        args = optional(list(string))
        autoscaling = optional(object({
          cpu_threshold = optional(string)
          max           = optional(number)
          min           = optional(number)
          ram_threshold = optional(string)
          scaling_on    = optional(string)
        }))
        command = optional(list(string))
        health_checks = optional(object({
          liveness_check_type     = optional(string)
          liveness_exec_command   = optional(list(any))
          liveness_period         = optional(number)
          liveness_port           = optional(string)
          liveness_start_up_time  = optional(number)
          liveness_timeout        = optional(number)
          liveness_url            = optional(string)
          readiness_check_type    = optional(string)
          readiness_exec_command  = optional(list(any))
          readiness_period        = optional(number)
          readiness_port          = optional(string)
          readiness_start_up_time = optional(number)
          readiness_timeout       = optional(number)
          readiness_url           = optional(string)
          startup_check_type      = optional(string)
          startup_exec_command    = optional(list(any))
          startup_headers         = optional(map(string), {})
          startup_period          = optional(number)
          startup_port            = optional(string)
          startup_start_up_time   = optional(number)
          startup_timeout         = optional(number)
          startup_url             = optional(string)
        }))
        metrics = optional(map(any))
        ports   = map(any)
        size = object({
          cpu          = string
          cpu_limit    = optional(string)
          memory       = string
          memory_limit = optional(string)
        })
        volumes = optional(object({
          config_maps = optional(map(any))
          host_path   = optional(map(any))
          pvc         = optional(map(any))
          secrets     = optional(map(any))
        }))
      })
      sidecars = optional(map(any))
      type     = string
    })
    # Escape hatch for raw application chart values (merged in main.tf).
    advanced = optional(object({
      common = optional(object({
        app_chart = optional(object({
          values = optional(any, {})
        }), {})
      }), {})
    }), {})
  })
}

variable "instance_name" {
  type        = string
  description = "Resource name in the blueprint (architectural name, e.g. main-db, api)"
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

variable "inputs" {
  description = "Input dependencies from other resources defined in facets.yaml inputs section"
  type = object({
    # @facets/kubernetes-details (attributes output of kubernetes_cluster/anycloud) — providers only.
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider   = optional(string)
        cluster_id       = optional(string)
        cluster_name     = optional(string)
        cluster_location = optional(string)
        cluster_endpoint = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    # @facets/any_cloud_kubernetes_cluster (default output) — EKS OIDC for IRSA.
    kubernetes_cluster = object({
      attributes = optional(object({
        cloud_provider = optional(string)
        cluster_name   = optional(string)
      }), {})
      interfaces = optional(object({
        aws = optional(object({
          cluster_arn               = optional(string)
          oidc_issuer_url           = optional(string)
          oidc_provider             = optional(string)
          oidc_provider_arn         = optional(string)
          node_security_group_id    = optional(string)
          cluster_security_group_id = optional(string)
        }))
        gcp = optional(object({
          project_id          = optional(string)
          pods_range_name     = optional(string)
          services_range_name = optional(string)
          network             = optional(string)
          subnetwork          = optional(string)
          oidc_issuer_url     = optional(string)
        }))
      }), {})
    })
    cloud_account = object({
      attributes = optional(object({
        cloud_provider = optional(string)
        aws = optional(object({
          region      = optional(string)
          role_arn    = optional(string)
          external_id = optional(string)
        }))
        gcp = optional(object({
          project_id = optional(string)
          region     = optional(string)
        }))
      }), {})
      interfaces = optional(object({}), {})
    })
    kubernetes_node_pool_details = optional(object({
      attributes = optional(object({
        node_pool_name = optional(string)
        node_selector  = optional(map(string), {})
        taints = optional(list(object({
          key    = optional(string)
          value  = optional(string)
          effect = optional(string)
        })), [])
      }), {})
      interfaces = optional(object({}), {})
    }))
    artifactories = optional(object({
      attributes = optional(object({
        registry_secrets_list = optional(list(object({
          name = string
        })), [])
      }), {})
      interfaces = optional(object({}), {})
    }))
  })
}
