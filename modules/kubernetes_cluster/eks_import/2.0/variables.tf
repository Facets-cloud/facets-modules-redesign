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
      node_subnet_ids                 = optional(list(string), [])

      # Import knobs — MUST be declared here or terraform's object typing drops them from
      # var.instance.spec and every lookup() below silently falls back to its create-mode default.
      cluster_name_override      = optional(string, "")
      node_iam_role_arn_override = optional(string, "")
      kms_key_arn                = optional(string, "")
      cluster_security_group_id  = optional(string, "")
      node_security_group_id     = optional(string, "")
      cluster_iam_role_arn       = optional(string, "")
      create_cluster_iam_role    = optional(bool, true)
      authentication_mode        = optional(string, "API_AND_CONFIG_MAP")
      service_ipv4_cidr          = optional(string, "")
      control_plane_subnet_ids   = optional(list(string), [])
      create_kms_alias           = optional(bool, true)
      create_cluster_sg          = optional(bool, true)
      create_node_sg             = optional(bool, true)
      create_sg_rules            = optional(bool, true)
      create_primary_sg_tags     = optional(bool, true)
      create_ebs_csi_driver_role = optional(bool, true)
      enable_access_entries      = optional(bool, true)
      enable_eks_auto_mode       = optional(bool, false)

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

      cloudwatch_agent_policies = optional(map(object({
        arn = string
      })), {})

      enabled_log_types = optional(list(string), ["api", "audit", "authenticator", "controllerManager", "scheduler"])

      cluster_tags = optional(map(string), {})
    })
  })

  validation {
    condition     = contains(["1.28", "1.29", "1.30", "1.31", "1.32", "1.33", "1.34", "1.35", "1.36"], var.instance.spec.cluster_version)
    error_message = "Kubernetes version must be one of: 1.28, 1.29, 1.30, 1.31, 1.32, 1.33, 1.34, 1.35, 1.36"
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
        aws_account_id = optional(string)
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
