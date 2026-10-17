variable "instance" {
  type = object({
    spec = optional(object({
      acme_email             = optional(string)
      manage_cluster_issuers = optional(bool)
      # `any` on purpose: each issuer carries a free-form ACME solvers block (dns01/route53,
      # http01/ingress, …) whose shape differs per issuer. A strict object here would silently
      # DROP the whole field — terraform discards attributes this type does not declare, with
      # no error, which is exactly how the first attempt at this failed.
      cluster_issuers = optional(any)
      cert_manager = optional(object({
        values          = optional(any)
        cleanup_on_fail = optional(bool)
        wait            = optional(bool)
        atomic          = optional(bool)
        timeout         = optional(number)
        recreate_pods   = optional(bool)
      }))
    }))
  })
}

variable "instance_name" {
  type    = string
  default = "test_instance"
}

variable "environment" {
  type = any
  default = {
    namespace = "default"
  }
}

variable "inputs" {
  type = object({
    prometheus_details = optional(object({
      attributes = optional(object({
        alertmanager_url = optional(string)
        helm_release_id  = optional(string)
        prometheus_url   = optional(string)
      }))
      interfaces = optional(object({}))
    }))
    kubernetes_details = object({
      cloud_provider   = optional(string)
      cluster_id       = optional(string)
      cluster_name     = optional(string)
      cluster_location = optional(string)
      cluster_endpoint = optional(string)
    })
    kubernetes_node_pool_details = optional(object({
      attributes = optional(object({
        node_class_name = optional(string)
        node_pool_name  = optional(string)
        taints = optional(list(object({
          key    = string
          value  = string
          effect = string
        })), [])
        node_selector = optional(map(string), {})
      }))
      interfaces = optional(object({}))
    }), {})
    gateway_api_crd_details = optional(object({
      attributes = optional(object({
        version     = optional(string)
        channel     = optional(string)
        install_url = optional(string)
        job_name    = optional(string)
        namespace   = optional(string)
      }))
      interfaces = optional(object({}))
    }))
  })
}
