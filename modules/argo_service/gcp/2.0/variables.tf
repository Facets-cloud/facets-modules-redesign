variable "instance" {
  description = "argo_service/gcp resource instance - mirrors the facets.yaml spec schema."
  type = object({
    kind    = optional(string)
    flavor  = optional(string)
    version = optional(string)
    spec = object({
      argocd_project = optional(string, "default")
      namespace      = string

      chart = object({
        repo_url     = string
        revision     = optional(string, "develop")
        path         = string
        values_path  = string
        release_name = optional(string, "")
      })

      sync_policy = optional(object({
        automated          = optional(bool, true)
        auto_prune         = optional(bool, false)
        self_heal          = optional(bool, false)
        preserve_on_delete = optional(bool, true)
        retry = optional(object({
          limit = optional(number, 5)
        }), {})
      }), {})

      helm_values = optional(map(any), {})
      annotations = optional(map(string), {})

      # Written back by the facets-argo-shim consumed-references callback as
      # { "<env>": { "expressions": [ "${...}", ... ] } }. The CP resolves the
      # expressions before this module runs, so the values that arrive here are
      # already resolved - the element type is therefore any, not string.
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
  })
}

variable "inputs" {
  description = "Wired dependencies for this module."
  type = object({
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider   = optional(string)
        cluster_id       = optional(string)
        cluster_name     = optional(string)
        cluster_location = optional(string)
        cluster_endpoint = optional(string)
      }), {})
      interfaces = optional(object({
        kubernetes = optional(object({
          cluster_ca_certificate = optional(string)
          host                   = optional(string)
        }), {})
      }), {})
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
        # facets-argo-shim state, published by argo/gcp >= 1.1. Optional so a
        # 1.0 stack still type-checks; the precondition in main.tf is what
        # actually enforces it.
        shim_enabled = optional(bool, false)
        shim_version = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}
