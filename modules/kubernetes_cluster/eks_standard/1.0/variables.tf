variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      cluster_version                 = string
      cluster_endpoint_public_access  = optional(bool, true)
      cluster_endpoint_private_access = optional(bool, true)
      customer_managed_kms            = optional(bool, true)

      cluster_addons = optional(object({
        vpc_cni = optional(object({
          enabled = optional(bool, true)
          version = optional(string, "latest")
        }), {})
        kube_proxy = optional(object({
          enabled = optional(bool, true)
          version = optional(string, "latest")
        }), {})
        coredns = optional(object({
          enabled = optional(bool, true)
          version = optional(string, "latest")
        }), {})
        ebs_csi = optional(object({
          enabled = optional(bool, true)
          version = optional(string, "latest")
        }), {})
        additional_addons = optional(map(object({
          enabled                  = optional(bool, true)
          version                  = optional(string, "latest")
          configuration_values     = optional(string)
          service_account_role_arn = optional(string)
        })), {})
      }), {})

      container_insights_enabled = optional(bool, false)

      enabled_log_types = optional(list(string), ["api", "audit", "authenticator", "controllerManager", "scheduler"])

      cluster_tags = optional(map(string), {})
    })
  })

  validation {
    condition     = contains(["1.28", "1.29", "1.30", "1.31", "1.32", "1.33", "1.34", "1.35", "1.36", "1.37"], var.instance.spec.cluster_version)
    error_message = "Kubernetes version must be one of: 1.28, 1.29, 1.30, 1.31, 1.32, 1.33, 1.34, 1.35, 1.36, 1.37"
  }

  validation {
    condition = (
      var.instance.spec.enabled_log_types == null ||
      alltrue([
        for log_type in var.instance.spec.enabled_log_types :
        contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], log_type)
      ])
    )
    error_message = "enabled_log_types must be from: api, audit, authenticator, controllerManager, scheduler."
  }
}

variable "instance_name" {
  type        = string
  description = "Unique architectural name from blueprint"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
  description = "Environment context including name and cloud tags"
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = object({
        aws_region     = string
        aws_account_id = string
        aws_iam_role   = string
        external_id    = optional(string)
        session_name   = optional(string)
      })
    })
    network_details = object({
      attributes = object({
        vpc_id             = string
        private_subnet_ids = list(string)
        public_subnet_ids  = optional(list(string), [])
      })
    })
  })
  description = "Inputs from dependent modules"
}
