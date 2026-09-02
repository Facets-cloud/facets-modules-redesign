variable "instance" {
  description = "Managed Memorystore for Valkey instance connected through Private Service Connect"
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
    spec = object({
      version_config = object({
        engine_version = optional(string, "VALKEY_7_2")
        mode           = optional(string, "CLUSTER_DISABLED")
      })
      sizing = object({
        node_type     = optional(string, "SHARED_CORE_NANO")
        shard_count   = optional(number, 1)
        replica_count = optional(number, 0)
      })
      security = object({
        enable_tls         = optional(bool, true)
        authorization_mode = optional(string, "AUTH_DISABLED")
      })
      engine_config = object({
        database_count   = optional(number, 16)
        maxmemory_policy = optional(string, "volatile-lru")
      })
      maintenance = optional(object({
        day    = optional(string, "MONDAY")
        hour   = optional(number, 22)
        minute = optional(number, 0)
      }), { day = "MONDAY", hour = 22, minute = 0 })
      backup = optional(object({
        enabled        = optional(bool, false)
        retention_days = optional(number, 1)
        start_hour     = optional(number, 21)
      }), { enabled = false, retention_days = 1, start_hour = 21 })
    })
  })

  validation {
    condition     = contains(["CLUSTER_DISABLED", "CLUSTER", "CLUSTER_ENABLED"], var.instance.spec.version_config.mode)
    error_message = "mode must be CLUSTER_DISABLED, CLUSTER, or CLUSTER_ENABLED (normalised to CLUSTER)."
  }

  # CLUSTER_DISABLED is a single primary, so exactly one shard. CLUSTER_ENABLED
  # may shard; the API still requires at least one.
  validation {
    condition = (var.instance.spec.version_config.mode == "CLUSTER_DISABLED"
      ? var.instance.spec.sizing.shard_count == 1
    : var.instance.spec.sizing.shard_count >= 1)
    error_message = "CLUSTER_DISABLED Valkey supports exactly one shard; CLUSTER_ENABLED requires at least one."
  }

  # Logical databases exist only in CLUSTER_DISABLED mode - a cluster has db 0 and
  # nothing else, and the module does not send engine_configs.databases there. The
  # >= 11 floor keeps DB index 10 available for the services that address one.
  validation {
    condition = (var.instance.spec.version_config.mode != "CLUSTER_DISABLED" ||
      (var.instance.spec.engine_config.database_count >= 11
    && var.instance.spec.engine_config.database_count <= 100))
    error_message = "database_count must be between 11 and 100 so DB index 10 is available (CLUSTER_DISABLED only)."
  }

  validation {
    condition     = contains(["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"], var.instance.spec.maintenance.day)
    error_message = "Maintenance day must be a weekday enum value."
  }

  validation {
    condition     = var.instance.spec.maintenance.hour >= 0 && var.instance.spec.maintenance.hour <= 23
    error_message = "Maintenance hour must be between 0 and 23 UTC."
  }

  # The Memorystore API accepts WHOLE HOURS ONLY for a maintenance start time:
  #   Error 400: Invalid start time, only hours are supported
  # The field is kept (removing it would break existing blueprints) but pinned to
  # 0, so the rejection surfaces at plan time rather than mid-apply.
  validation {
    condition     = var.instance.spec.maintenance.minute == 0
    error_message = "Maintenance minute must be 0 - the Memorystore API supports whole hours only."
  }

  # Memorystore caps automated-backup retention at 1-365 days, and start_time
  # accepts whole hours only - there is no minutes attribute on that block.
  validation {
    condition = (try(var.instance.spec.backup, null) == null ? true :
      (coalesce(try(var.instance.spec.backup.retention_days, 1), 1) >= 1 &&
    coalesce(try(var.instance.spec.backup.retention_days, 1), 1) <= 365))
    error_message = "backup.retention_days must be between 1 and 365."
  }

  validation {
    condition = (try(var.instance.spec.backup, null) == null ? true :
      (coalesce(try(var.instance.spec.backup.start_hour, 21), 21) >= 0 &&
    coalesce(try(var.instance.spec.backup.start_hour, 21), 21) <= 23))
    error_message = "backup.start_hour must be between 0 and 23 UTC (whole hours only)."
  }
}

variable "instance_name" {
  description = "Resource name in the Facets blueprint."
  type        = string
}

variable "environment" {
  description = "Environment context."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "Input references from other modules."
  type = object({
    gcp_provider = object({
      attributes = optional(object({
        project_id  = optional(string, "")
        credentials = optional(string, "")
        region      = optional(string, "")
      }), {})
      interfaces = optional(object({}), {})
    })
    network = object({
      attributes = optional(object({
        project_id           = optional(string, "")
        region               = optional(string, "")
        vpc_self_link        = optional(string, "")
        vpc_name             = optional(string, "")
        private_subnet_ids   = optional(list(string), [])
        private_subnet_cidrs = optional(list(string), [])
      }), {})
      interfaces = optional(object({}), {})
    })
    service_connection_policy = object({
      attributes = optional(object({
        id               = optional(string, "")
        name             = optional(string, "")
        project_id       = optional(string, "")
        region           = optional(string, "")
        network          = optional(string, "")
        service_class    = optional(string, "")
        connection_limit = optional(number, 0)
        subnetworks      = optional(list(string), [])
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}
