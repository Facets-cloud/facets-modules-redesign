variable "instance_name" {
  type        = string
  description = "The name of the GKE cluster instance"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
  description = "Environment configuration with name, unique_name, and cloud_tags"
}

variable "instance" {
  type = object({
    spec = object({
      cluster = object({
        cluster_endpoint_public_access_cidrs = list(string)
      })
      auto_upgrade_settings = object({
        release_channel = string
        maintenance_window = object({
          is_enabled = bool
          start_time = string
          end_time   = string
          recurrence = string
        })
      })
      system_node_pool = object({
        enabled            = bool
        node_count         = number
        machine_type       = string
        disk_size_gb       = number
        disk_type          = string
        enable_autoscaling = bool
        min_nodes          = number
        max_nodes          = number
        labels             = map(string)
      })
      security = object({
        enable_private_cluster   = bool
        enable_network_policy    = bool
        enable_workload_identity = bool
        master_ipv4_cidr_block   = string
      })
      logging = object({
        enable_logging                   = bool
        log_retention_days               = number
        enable_workloads_logging         = bool
        enable_api_server_logging        = bool
        enable_system_components_logging = bool
      })
      tags = map(string)
    })
  })
  description = "Instance configuration containing the spec"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.instance.spec.auto_upgrade_settings.release_channel)
    error_message = "Release channel must be one of 'RAPID', 'REGULAR', or 'STABLE'."
  }

  validation {
    condition     = contains(["pd-standard", "pd-ssd", "pd-balanced"], var.instance.spec.system_node_pool.disk_type)
    error_message = "Disk type must be one of 'pd-standard', 'pd-ssd', or 'pd-balanced'."
  }

  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.instance.spec.auto_upgrade_settings.maintenance_window.start_time))
    error_message = "Start time must be in HH:MM format (24-hour)."
  }

  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.instance.spec.auto_upgrade_settings.maintenance_window.end_time))
    error_message = "End time must be in HH:MM format (24-hour)."
  }

  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}\\/\\d{1,2}$", var.instance.spec.security.master_ipv4_cidr_block))
    error_message = "Master IPv4 CIDR block must be a valid CIDR block."
  }

  validation {
    condition     = var.instance.spec.system_node_pool.node_count >= 1 && var.instance.spec.system_node_pool.node_count <= 1000
    error_message = "Node count must be between 1 and 1000."
  }

  validation {
    condition     = var.instance.spec.system_node_pool.disk_size_gb >= 10 && var.instance.spec.system_node_pool.disk_size_gb <= 65536
    error_message = "Disk size must be between 10 and 65536 GB."
  }

  validation {
    condition     = var.instance.spec.system_node_pool.min_nodes >= 0 && var.instance.spec.system_node_pool.min_nodes <= 1000
    error_message = "Minimum nodes must be between 0 and 1000."
  }

  validation {
    condition     = var.instance.spec.system_node_pool.max_nodes >= 1 && var.instance.spec.system_node_pool.max_nodes <= 1000
    error_message = "Maximum nodes must be between 1 and 1000."
  }

  validation {
    condition     = var.instance.spec.system_node_pool.max_nodes >= var.instance.spec.system_node_pool.min_nodes
    error_message = "Maximum nodes must be greater than or equal to minimum nodes."
  }

  validation {
    condition     = var.instance.spec.logging.log_retention_days >= 1 && var.instance.spec.logging.log_retention_days <= 3653
    error_message = "Log retention days must be between 1 and 3653."
  }
}

variable "inputs" {
  type = object({
    network_details = object({
      attributes = object({
        network_self_link   = string
        subnet_self_link    = string
        region              = string
        project_id          = string
        pods_range_name     = string
        services_range_name = string
      })
    })
  })
  description = "Input dependencies from other modules"
}