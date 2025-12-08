variable "instance" {
  description = "The instance configuration for the AKS cluster"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      cluster = object({
        cluster_endpoint_public_access_cidrs = optional(list(string), ["0.0.0.0/0"])
        sku_tier                             = optional(string, "Free")
      })
      auto_upgrade_settings = object({
        automatic_channel_upgrade = optional(string, "stable")
        max_surge                 = optional(string, "1")
        maintenance_window = object({
          is_enabled   = optional(bool, true)
          frequency    = optional(string, "Weekly")
          interval     = optional(number, 1)
          day_of_week  = optional(string, "Sunday")
          day_of_month = optional(number, 1)
          week_index   = optional(string, "First")
          start_time   = optional(number, 2)
          end_time     = optional(number, 6)
        })
      })
      node_pools = object({
        system_np = object({
          enabled             = optional(bool, true)
          node_count          = optional(number, 1)
          instance_type       = optional(string, "Standard_D2_v4")
          max_pods            = optional(number, 30)
          os_disk_size_gb     = optional(number, 50)
          enable_auto_scaling = optional(bool, false)
          labels = optional(map(string), {
            "facets.cloud/node-type" = "system"
            "managed-by"             = "facets"
          })
        })
      })
      tags = optional(map(string), {})
    })
  })

  validation {
    condition     = contains(["Free", "Standard"], var.instance.spec.cluster.sku_tier)
    error_message = "SKU tier must be one of: Free, Standard."
  }

  validation {
    condition     = var.instance.spec.node_pools.system_np.node_count >= 1 && var.instance.spec.node_pools.system_np.node_count <= 1000
    error_message = "System node pool node_count must be between 1 and 1000."
  }

  validation {
    condition     = var.instance.spec.node_pools.system_np.max_pods >= 10 && var.instance.spec.node_pools.system_np.max_pods <= 250
    error_message = "System node pool max_pods must be between 10 and 250."
  }

  validation {
    condition     = var.instance.spec.node_pools.system_np.os_disk_size_gb >= 30 && var.instance.spec.node_pools.system_np.os_disk_size_gb <= 2048
    error_message = "System node pool os_disk_size_gb must be between 30 and 2048."
  }

  validation {
    condition     = can(regex("^([0-9]+%?|[0-9]+)$", var.instance.spec.auto_upgrade_settings.max_surge))
    error_message = "Max surge must be a number or percentage (e.g., 1, 33%)."
  }

  validation {
    condition = contains([
      "rapid", "regular", "stable", "patch", "node-image"
    ], var.instance.spec.auto_upgrade_settings.automatic_channel_upgrade)
    error_message = "Automatic channel upgrade must be one of: rapid, regular, stable, patch, node-image."
  }

  validation {
    condition = contains([
      "Daily", "Weekly", "AbsoluteMonthly", "RelativeMonthly"
    ], var.instance.spec.auto_upgrade_settings.maintenance_window.frequency)
    error_message = "Maintenance window frequency must be one of: Daily, Weekly, AbsoluteMonthly, RelativeMonthly."
  }

  validation {
    condition = (
      var.instance.spec.auto_upgrade_settings.maintenance_window.interval >= 1 &&
      var.instance.spec.auto_upgrade_settings.maintenance_window.interval <= 12
    )
    error_message = "Maintenance window interval must be between 1 and 12."
  }

  validation {
    condition = contains([
      "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ], var.instance.spec.auto_upgrade_settings.maintenance_window.day_of_week)
    error_message = "Maintenance window day_of_week must be one of: Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday."
  }

  validation {
    condition = (
      var.instance.spec.auto_upgrade_settings.maintenance_window.day_of_month >= 1 &&
      var.instance.spec.auto_upgrade_settings.maintenance_window.day_of_month <= 31
    )
    error_message = "Maintenance window day_of_month must be between 1 and 31."
  }

  validation {
    condition = contains([
      "First", "Second", "Third", "Fourth", "Last"
    ], var.instance.spec.auto_upgrade_settings.maintenance_window.week_index)
    error_message = "Maintenance window week_index must be one of: First, Second, Third, Fourth, Last."
  }

  validation {
    condition = (
      var.instance.spec.auto_upgrade_settings.maintenance_window.start_time >= 0 &&
      var.instance.spec.auto_upgrade_settings.maintenance_window.start_time <= 23
    )
    error_message = "Maintenance window start_time must be between 0 and 23."
  }

  validation {
    condition = (
      var.instance.spec.auto_upgrade_settings.maintenance_window.end_time >= 0 &&
      var.instance.spec.auto_upgrade_settings.maintenance_window.end_time <= 23
    )
    error_message = "Maintenance window end_time must be between 0 and 23."
  }

  validation {
    condition = (
      var.instance.spec.auto_upgrade_settings.maintenance_window.end_time >
      var.instance.spec.auto_upgrade_settings.maintenance_window.start_time
    )
    error_message = "Maintenance window end_time must be greater than start_time."
  }
}

variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string

  validation {
    condition     = length(var.instance_name) > 0 && length(var.instance_name) <= 63
    error_message = "Instance name must be between 1 and 63 characters long."
  }

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.instance_name))
    error_message = "Instance name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })

  validation {
    condition     = length(var.environment.name) > 0
    error_message = "Environment name cannot be empty."
  }

  validation {
    condition     = length(var.environment.unique_name) > 0
    error_message = "Environment unique_name cannot be empty."
  }
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    network_details = object({
      attributes = object({
        vnet_id                    = string
        region                     = string
        resource_group_name        = string
        availability_zones         = list(string)
        private_subnet_ids         = list(string)
        public_subnet_ids          = list(string)
        log_analytics_workspace_id = optional(string, null)
      })
    })
    cloud_account = object({
      attributes = object({
        subscription_id = string
        tenant_id       = string
      })
    })
  })

  validation {
    condition     = length(var.inputs.network_details.attributes.vnet_id) > 0
    error_message = "VNet ID cannot be empty."
  }

  validation {
    condition     = length(var.inputs.network_details.attributes.region) > 0
    error_message = "Region cannot be empty."
  }

  validation {
    condition     = length(var.inputs.network_details.attributes.resource_group_name) > 0
    error_message = "Resource group name cannot be empty."
  }

  validation {
    condition     = length(var.inputs.network_details.attributes.availability_zones) > 0
    error_message = "At least one availability zone must be specified."
  }

  validation {
    condition     = length(var.inputs.network_details.attributes.private_subnet_ids) > 0
    error_message = "At least one private subnet ID must be specified."
  }

  validation {
    condition     = length(var.inputs.cloud_account.attributes.subscription_id) > 0
    error_message = "Azure subscription ID cannot be empty."
  }

  validation {
    condition     = length(var.inputs.cloud_account.attributes.tenant_id) > 0
    error_message = "Azure tenant ID cannot be empty."
  }
}
