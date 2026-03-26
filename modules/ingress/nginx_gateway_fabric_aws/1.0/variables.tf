variable "instance" {
  type = object({
    spec = object({
      private             = optional(bool, false)
      disable_base_domain = optional(bool, false)
      domains = optional(map(object({
        domain                = string
        alias                 = string
        certificate_reference = optional(string)
      })), {})
      data_plane             = optional(any)
      control_plane          = optional(any)
      rules                  = optional(any, {})
      force_ssl_redirection  = optional(bool, false)
      basic_auth             = optional(bool, false)
      body_size              = optional(string, "150m")
      helm_values            = optional(any, {})
      domain_prefix_override = optional(string)
      helm_wait              = optional(bool, true)
    })
  })
}

variable "instance_name" {
  type    = string
  default = ""
}

variable "inputs" {
  type = object({
    kubernetes_details = object({
      attributes = object({
        cloud_provider         = optional(string)
        cluster_id             = optional(string)
        cluster_name           = optional(string)
        cluster_location       = optional(string)
        cluster_endpoint       = optional(string)
        lb_service_record_type = optional(string)
      })
      interfaces = optional(object({
        kubernetes = optional(object({
          cluster_ca_certificate = optional(string)
          host                   = optional(string)
        }))
      }))
    })
    kubernetes_node_pool_details = optional(object({
      attributes = optional(object({
        labels        = optional(any)
        taints        = optional(any)
        node_selector = optional(any)
      }))
    }))
    artifactories = optional(object({
      attributes = optional(object({
        registry_secrets_list = optional(any)
      }))
    }))
    cert_manager_details = optional(object({
      attributes = optional(object({
        acme_email          = optional(string)
        cluster_issuer_http = optional(string)
      }))
    }))
    gateway_api_crd_details = object({
      attributes = object({
        version     = optional(string)
        channel     = optional(string)
        install_url = optional(string)
        job_name    = optional(string)
      })
    })
    prometheus_details = optional(object({
      attributes = optional(object({
        alertmanager_url = optional(string)
        helm_release_id  = optional(string)
        prometheus_url   = optional(string)
      }))
      interfaces = optional(object({}))
    }))
    aws_alb_controller_details = optional(object({
      attributes = optional(object({
        controller_namespace       = optional(string)
        controller_service_account = optional(string)
        controller_version         = optional(string)
        controller_role_arn        = optional(string)
        helm_release_id            = optional(string)
      }))
    }))
    ack_acm_controller_details = optional(object({
      attributes = optional(object({
        namespace       = optional(string)
        release_name    = optional(string)
        chart_version   = optional(string)
        role_arn        = optional(string)
        helm_release_id = optional(string)
      }))
    }))
  })
  description = "Inputs from other modules"
}


variable "environment" {
  type    = any
  default = {}
}
