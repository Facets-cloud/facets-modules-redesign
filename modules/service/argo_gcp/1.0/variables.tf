variable "instance" {
  description = "service/argo_gcp resource instance - mirrors the facets.yaml spec schema."
  type = object({
    kind    = optional(string)
    flavor  = optional(string)
    version = optional(string)
    spec = object({
      argocd_project = optional(string, "default")
      namespace      = string

      chart = object({
        repo_url     = string
        revision     = optional(string, "HEAD")
        path         = string
        values_path  = optional(string, "")
        release_name = optional(string, "")
      })

      release = optional(object({
        image             = optional(string, "")
        image_values_path = optional(string, "")
      }), {})

      sync_policy = optional(object({
        automated          = optional(bool, true)
        auto_prune         = optional(bool, false)
        self_heal          = optional(bool, true)
        preserve_on_delete = optional(bool, true)
        retry = optional(object({
          limit = optional(number, 5)
        }), {})
      }), {})

      helm_values = optional(map(any), {})

      workload_identity = optional(object({
        service_accounts = optional(map(object({
          enabled     = optional(bool, true)
          ksa_name    = optional(string, "")
          values_root = optional(string, "")
          roles = optional(map(object({
            role = string
          })), {})
          aws = optional(object({
            enabled  = optional(bool, false)
            region   = optional(string, "ap-south-1")
            role_arn = optional(string, "")
          }), {})
        })), {})
      }), {})

      dns_record = optional(object({
        enabled   = optional(bool, false)
        zone_name = optional(string, "")
        name      = optional(string, "")
        target    = optional(string, "")
        ttl       = optional(number, 300)
      }), {})

      advanced = optional(object({
        ignore_differences    = optional(list(any), [])
        sync_options          = optional(list(string), [])
        application_overrides = optional(map(any), {})
      }), {})

      annotations = optional(map(string), {})

      # Written back by the facets-argo-shim consumed-references callback as
      # { "<env>": { "expressions": [ "${...}", ... ] } }. The CP resolves the
      # expressions before this module runs, so what arrives here is already
      # resolved - the element type is therefore any, not string.
      facets_references = optional(map(object({
        expressions = optional(list(any), [])
      })), {})
    })
  })
}

variable "instance_name" {
  description = "Blueprint resource name. Default service name, Helm release name, and ApplicationSet name."
  type        = string
}

variable "environment" {
  description = "Environment context. unique_name is \"<project>-<name>\" by construction."
  type = object({
    name        = string
    unique_name = string
    namespace   = optional(string)
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "Wired dependencies for this module."
  type = object({
    # RULE-006: kubernetes_cluster publishes @facets/kubernetes-details under its
    # `attributes` output KEY, not `default`, so the platform injects these
    # fields FLAT - no attributes/interfaces wrapper. (argo/gcp/1.1, which is
    # deployed and working, declares it the same way.) Nothing in this module
    # reads these today; the input exists to carry the kubernetes and helm
    # providers, which is why the wrapped form went unnoticed.
    kubernetes_details = object({
      cloud_provider   = optional(string)
      cluster_id       = optional(string)
      cluster_name     = optional(string)
      cluster_location = optional(string)
      cluster_endpoint = optional(string)
    })

    cloud_account = object({
      attributes = optional(object({
        project_id  = optional(string)
        region      = optional(string)
        credentials = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })

    argo_stack = object({
      attributes = optional(object({
        argocd_namespace           = optional(string)
        argocd_server_service      = optional(string)
        workflows_namespace        = optional(string)
        workflows_server_service   = optional(string)
        workflows_sa_email         = optional(string)
        events_namespace           = optional(string)
        rollouts_namespace         = optional(string)
        rollouts_dashboard_service = optional(string)
        shim_enabled               = optional(bool, false)
        shim_version               = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}
