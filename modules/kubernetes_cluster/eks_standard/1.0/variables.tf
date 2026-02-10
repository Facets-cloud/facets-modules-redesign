variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      cluster_version                 = string
      cluster_endpoint_public_access  = optional(bool, true)
      cluster_endpoint_private_access = optional(bool, true)
      enable_cluster_encryption       = optional(bool, true)

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

      managed_node_groups = optional(map(object({
        instance_types = optional(list(string), ["t3.medium"])
        min_size       = optional(number, 1)
        max_size       = optional(number, 10)
        desired_size   = optional(number, 2)
        capacity_type  = optional(string, "ON_DEMAND")
        disk_size      = optional(number, 50)
        labels         = optional(map(string), {})
        taints         = optional(map(string), {})
      })), {})

      container_insights_enabled = optional(bool, true)

      cluster_tags = optional(map(string), {})
    })
  })

  validation {
    condition     = contains(["1.28", "1.29", "1.30", "1.31", "1.32", "1.33", "1.34", "1.35", "1.36", "1.37"], var.instance.spec.cluster_version)
    error_message = "Kubernetes version must be one of: 1.28, 1.29, 1.30, 1.31, 1.32, 1.33, 1.34, 1.35, 1.36, 1.37"
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
