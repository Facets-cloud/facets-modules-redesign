variable "instance" {
  description = "A Kubernetes EKS cluster module with auto mode enabled by default and all necessary configurations preset."
  type = object({
    spec = object({
      cluster = object({
        cluster_endpoint_public_access        = optional(bool, true)
        cluster_endpoint_public_access_cidrs  = optional(list(string), ["0.0.0.0/0"])
        cluster_endpoint_private_access_cidrs = optional(list(string), [])
        cluster_service_ipv4_cidr             = optional(string)
        cloudwatch = optional(object({
          log_group_retention_in_days  = optional(number, 90)
          enabled_log_types            = optional(list(string), ["api", "audit", "authenticator", "controllerManager", "scheduler"])
          container_insights_enabled   = optional(bool, true)
        }), {})
        cluster_addons = optional(map(object({
          name                        = string
          enabled                     = optional(bool, true)
          configuration_values        = optional(any, {})
          service_account_role_arn    = optional(string)
          addon_version               = optional(string)
          resolve_conflicts_on_create = optional(string)
          resolve_conflicts_on_update = optional(string)
        })), {})
      })
      tags = optional(any, {})
    })
  })

  # Validation for cluster_addons structure
  validation {
    condition = alltrue([
      for addon_name, addon_config in var.instance.spec.cluster.cluster_addons : (
        can(addon_config.enabled) &&
        (addon_config.enabled == true || addon_config.enabled == false)
      )
    ])
    error_message = "Each addon in cluster_addons must have an 'enabled' field set to true or false."
  }

  # Validation for resolve_conflicts_on_create values
  validation {
    condition = alltrue([
      for addon_name, addon_config in var.instance.spec.cluster.cluster_addons : (
        addon_config.resolve_conflicts_on_create == null ||
        contains(["OVERWRITE", "NONE"], addon_config.resolve_conflicts_on_create)
      )
    ])
    error_message = "resolve_conflicts_on_create must be either 'OVERWRITE' or 'NONE'."
  }

  # Validation for resolve_conflicts_on_update values
  validation {
    condition = alltrue([
      for addon_name, addon_config in var.instance.spec.cluster.cluster_addons : (
        addon_config.resolve_conflicts_on_update == null ||
        contains(["OVERWRITE", "NONE", "PRESERVE"], addon_config.resolve_conflicts_on_update)
      )
    ])
    error_message = "resolve_conflicts_on_update must be one of 'OVERWRITE', 'NONE', or 'PRESERVE'."
  }

  # Validation for addon_version format
  validation {
    condition = alltrue([
      for addon_name, addon_config in var.instance.spec.cluster.cluster_addons : (
        addon_config.addon_version == null ||
        can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+-eksbuild\\.[0-9]+$", addon_config.addon_version))
      )
    ])
    error_message = "addon_version must be in the format 'vX.Y.Z-eksbuild.N' (e.g., 'v8.0.0-eksbuild.1')."
  }

  # Validation for CloudWatch log retention days
  validation {
    condition = (
      var.instance.spec.cluster.cloudwatch.log_group_retention_in_days == null ||
      contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653],
      var.instance.spec.cluster.cloudwatch.log_group_retention_in_days)
    )
    error_message = "CloudWatch log_group_retention_in_days must be one of: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, or 3653 days."
  }

  # Validation for CloudWatch enabled_log_types
  validation {
    condition = (
      var.instance.spec.cluster.cloudwatch.enabled_log_types == null ||
      alltrue([
        for log_type in var.instance.spec.cluster.cloudwatch.enabled_log_types :
        contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], log_type)
      ])
    )
    error_message = "CloudWatch enabled_log_types must be from: api, audit, authenticator, controllerManager, scheduler."
  }

  # Validation for cluster_endpoint_public_access_cidrs format
  validation {
    condition = alltrue([
      for cidr in var.instance.spec.cluster.cluster_endpoint_public_access_cidrs :
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))
    ])
    error_message = "cluster_endpoint_public_access_cidrs must contain valid CIDR blocks (e.g., '0.0.0.0/0' or '10.0.0.0/16')."
  }

  # Validation for cluster_endpoint_private_access_cidrs format
  validation {
    condition = alltrue([
      for cidr in var.instance.spec.cluster.cluster_endpoint_private_access_cidrs :
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))
    ])
    error_message = "cluster_endpoint_private_access_cidrs must contain valid CIDR blocks (e.g., '10.0.0.0/16')."
  }

  # Validation for cluster_service_ipv4_cidr format
  validation {
    condition = (
      var.instance.spec.cluster.cluster_service_ipv4_cidr == null ||
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.instance.spec.cluster.cluster_service_ipv4_cidr))
    )
    error_message = "cluster_service_ipv4_cidr must be a valid CIDR block (e.g., '10.100.0.0/16')."
  }
}

variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
  validation {
    condition     = var.instance_name != null
    error_message = "instance_name is required"
  }
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.instance_name)) && length(var.instance_name) <= 20
    error_message = "Instance name must contain only alphanumeric characters and hyphens (-), and be no more than 20 characters long."
  }
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    network_details = object({
      attributes = object({
        vpc_id             = string
        vpc_cidr_block     = string
        private_subnet_ids = list(string)
      })
    })
    cloud_account = any
  })

  # Validation for network_details input
  validation {
    condition = (
      can(var.inputs.network_details) &&
      can(var.inputs.network_details.attributes) &&
      can(var.inputs.network_details.attributes.vpc_id) &&
      can(var.inputs.network_details.attributes.private_subnet_ids)
    )
    error_message = "inputs.network_details must contain attributes.vpc_id and attributes.private_subnet_ids."
  }

  # Validation for cloud_account input
  validation {
    condition     = can(var.inputs.cloud_account)
    error_message = "inputs.cloud_account is required for AWS provider configuration."
  }
}
