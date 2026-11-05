variable "instance_name" {
  description = "Name of the argo stack instance"
  type        = string
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "Input references from other modules"
  type = object({
    kubernetes_details = object({
      cluster_name     = string
      cluster_location = string
      cluster_endpoint = string
      project_id       = string
      region           = string
    })
    cloud_account = object({
      attributes = object({
        project_id = string
        region     = string
      })
    })
    # Optional in facets.yaml, so every attribute is optional and the object
    # itself defaults to {} — Argo pods then schedule without a node selector
    # or tolerations rather than failing to plan.
    node_pool = optional(object({
      node_selector       = optional(map(string), {})
      taints              = optional(list(any), [])
      node_pool_name      = optional(string)
      service_account     = optional(string)
      topology_spread_key = optional(string)
    }), {})

  })
}

# RULE-025: fully typed, no `type = any`. Every field is optional with a
# default so the existing lookup()-based reads in locals.tf keep working and an
# omitted block is an empty object rather than a plan error.
variable "instance" {
  description = "argo/gcp resource instance - mirrors the facets.yaml spec schema."
  type = object({
    kind    = optional(string)
    flavor  = optional(string)
    version = optional(string)
    spec = object({
      argocd = optional(object({
        enabled       = optional(bool, true)
        chart_version = optional(string, "9.4.16")
        namespace     = optional(string, "argocd")
        custom_values = optional(map(any), {})
        facets_shim = optional(object({
          enabled                     = optional(bool, false)
          image                       = optional(string, "docker.io/facetscloud/facets-argo-shim:v0.13.1")
          argocd_image                = optional(string, "quay.io/argoproj/argocd:v3.3.5")
          credentials_secret          = optional(string, "facets-cp-credentials")
          rbac_name                   = optional(string, "")
          repo_server_service_account = optional(string, "argo-cd-argocd-repo-server")
        }), {})
      }), {})

      workflows = optional(object({
        enabled                   = optional(bool, true)
        chart_version             = optional(string, "1.0.6")
        custom_values             = optional(map(any), {})
        create_service_account    = optional(bool, true)
        service_account_namespace = optional(string, "argocd")
      }), {})

      events = optional(object({
        enabled       = optional(bool, true)
        chart_version = optional(string, "2.4.21")
        namespace     = optional(string, "")
        custom_values = optional(map(any), {})
      }), {})

      rollouts = optional(object({
        enabled       = optional(bool, true)
        chart_version = optional(string, "2.40.8")
        custom_values = optional(map(any), {})
      }), {})

      workflows_sa_roles = optional(map(object({
        role = string
      })), {})
    })
  })
}
