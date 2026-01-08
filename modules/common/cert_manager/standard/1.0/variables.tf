variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
  default     = "cert-manager"
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = optional(string)
    unique_name = optional(string)
    namespace   = optional(string, "default")
  })
  default = {
    namespace = "default"
  }
}

variable "instance" {
  description = "The cert-manager resource instance configuration"
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
    spec = optional(object({
      # ACME configuration
      acme_email             = optional(string, "")
      cname_strategy         = optional(string, "Follow")
      disable_dns_validation = optional(bool, false)
      # Google Trust Services (GTS) configuration
      use_gts         = optional(bool, false)
      gts_private_key = optional(string, "")
    }), {})
    advanced = optional(object({
      cert_manager = optional(object({
        cleanup_on_fail = optional(bool, true)
        wait            = optional(bool, true)
        atomic          = optional(bool, false)
        timeout         = optional(number, 600)
        recreate_pods   = optional(bool, false)
        values          = optional(map(any), {})
      }), {})
    }), {})
  })
  default = {}
}

variable "inputs" {
  description = "Input dependencies from other modules"
  type = object({
    # Kubernetes cluster details (required)
    kubernetes_details = object({
      attributes = object({
        cluster_name     = string
        cluster_endpoint = optional(string)
        cloud_provider   = optional(string)
      })
      interfaces = optional(any)
    })
    # External DNS details (optional - required for DNS01 validation)
    external_dns_details = optional(object({
      attributes = object({
        provider         = string # "aws", "gcp", or "azure"
        secret_name      = string
        secret_namespace = string
        region           = optional(string, "")
        # AWS-specific fields
        aws_access_key_id_key     = optional(string, "")
        aws_secret_access_key_key = optional(string, "")
        # GCP-specific fields
        gcp_credentials_json_key = optional(string, "")
        project_id               = optional(string, "")
        # Azure-specific fields
        azure_credentials_json_key = optional(string, "")
        subscription_id            = optional(string, "")
        tenant_id                  = optional(string, "")
        client_id                  = optional(string, "")
        resource_group_name        = optional(string, "")
      })
    }), null)
    # Prometheus details (optional - for monitoring)
    prometheus_details = optional(object({
      attributes = object({
        helm_release_id = optional(string, "")
      })
    }), null)
    # Node pool details (optional - for dedicated scheduling)
    kubernetes_node_pool_details = optional(object({
      attributes = optional(object({
        node_selector = optional(map(string), {})
        # taints can be null, empty list, or list of taint objects
        # Using any type to handle all cases, conversion happens in locals.tf
        taints = optional(any, null)
      }), {})
    }), null)
  })
}
