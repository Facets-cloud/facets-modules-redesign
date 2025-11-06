# Use existing private services connection from network module
# No need to create new private IP range or service networking connection
# The network module already provides these resources

# Random password for MySQL root user (when not restoring from backup or importing user)
resource "random_password" "mysql_password" {
  count   = (var.instance.spec.restore_config.restore_from_backup || try(var.instance.spec.imports.root_user, "") != "") ? 0 : 1
  length  = 16
  special = true

  lifecycle {
    ignore_changes = all # Never regenerate password once created
  }
}

# CloudSQL MySQL instance
# NOTE: Read replicas must be deleted before the master instance can be deleted
resource "google_sql_database_instance" "mysql_instance" {
  name                = "${var.instance_name}-${var.environment.unique_name}"
  database_version    = "MYSQL_${replace(var.instance.spec.version_config.version, ".", "_")}"
  region              = var.inputs.network.attributes.region
  deletion_protection = false

  # Use existing private services connection from network module
  # Connection dependency is managed by the network module

  # Clone configuration for restore operations
  dynamic "clone" {
    for_each = var.instance.spec.restore_config.restore_from_backup ? [1] : []
    content {
      source_instance_name = var.instance.spec.restore_config.source_instance_id
    }
  }

  settings {
    tier = var.instance.spec.sizing.tier

    # Disk configuration
    disk_size             = var.instance.spec.sizing.disk_size
    disk_type             = "PD_SSD"
    disk_autoresize       = true
    disk_autoresize_limit = var.instance.spec.sizing.disk_size * 2

    # High availability and backup configuration (hardcoded for security)
    availability_type = "REGIONAL"

    backup_configuration {
      enabled    = true
      start_time = "03:00"
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
      binary_log_enabled             = true
      transaction_log_retention_days = 7
    }

    # IP configuration for private networking using existing network module resources
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.inputs.network.attributes.vpc_self_link
      enable_private_path_for_google_cloud_services = true
      # Let CloudSQL use the existing private services range managed by network module
      allocated_ip_range = null
    }

    # Database flags for security and performance
    database_flags {
      name  = "slow_query_log"
      value = "on"
    }

    database_flags {
      name  = "log_output"
      value = "FILE"
    }

    # Maintenance window
    maintenance_window {
      day          = 7 # Sunday
      hour         = 3 # 3 AM
      update_track = "stable"
    }

    # User labels for resource management
    user_labels = merge(
      var.environment.cloud_tags,
      {
        managed-by = "facets"
        intent     = var.instance.kind
        flavor     = var.instance.flavor
      }
    )
  }

  # Comprehensive lifecycle management to prevent stale data errors and handle imports
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      name,                              # Ignore name changes for imported resources
      database_version,                  # Ignore version changes for imported resources
      region,                            # Ignore region changes for imported resources
      settings[0].disk_size,             # Allow auto-resize to work
      settings[0].disk_autoresize_limit, # Ignore autoresize limit changes
      settings[0].disk_type,             # Ignore disk type changes for imported resources
      settings[0].database_flags,        # Ignore database flag changes
      settings[0].user_labels,           # Ignore label changes
      settings[0].availability_type,     # Ignore availability changes
      settings[0].tier,                  # Ignore tier changes
      settings[0].backup_configuration,  # Ignore backup config changes
      settings[0].ip_configuration,      # Ignore IP configuration changes
      settings[0].maintenance_window,    # Ignore maintenance window changes
      clone,                             # Ignore clone configuration for imports
    ]
  }
}

# Initial database
resource "google_sql_database" "initial_database" {
  name            = var.instance.spec.version_config.database_name
  instance        = google_sql_database_instance.mysql_instance.name
  deletion_policy = "DELETE"

  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      name,            # Ignore name changes for imported resources
      instance,        # Ignore instance changes for imported resources
      charset,         # Ignore charset changes for imported resources
      collation,       # Ignore collation changes for imported resources
      deletion_policy, # Ignore deletion policy changes for imported resources
    ]
  }
}

# Root user configuration
resource "google_sql_user" "mysql_root_user" {
  name     = var.instance.spec.restore_config.restore_from_backup ? var.instance.spec.restore_config.master_username : "root"
  instance = google_sql_database_instance.mysql_instance.name
  password = var.instance.spec.restore_config.restore_from_backup ? var.instance.spec.restore_config.master_password : (
    try(var.instance.spec.imports.root_user, "") != "" ? var.instance.spec.imports.master_password : random_password.mysql_password[0].result
  )

  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      name,     # Ignore name changes for imported resources
      instance, # Ignore instance changes for imported resources
      host,     # Ignore host changes for imported resources
      password, # CRITICAL: Never overwrite existing passwords on import
    ]
  }
}

# Read replicas (if specified)
resource "google_sql_database_instance" "read_replica" {
  count                = var.instance.spec.sizing.read_replica_count
  name                 = "${var.instance_name}-${var.environment.unique_name}-replica-${count.index + 1}"
  database_version     = google_sql_database_instance.mysql_instance.database_version
  region               = var.inputs.network.attributes.region
  master_instance_name = google_sql_database_instance.mysql_instance.name
  deletion_protection  = false

  replica_configuration {
    failover_target = false
  }

  settings {
    tier = var.instance.spec.sizing.tier

    # IP configuration matching master - using existing network module resources
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.inputs.network.attributes.vpc_self_link
      enable_private_path_for_google_cloud_services = true
      # Let CloudSQL use the existing private services range managed by network module
      allocated_ip_range = null
    }

    # User labels
    user_labels = merge(
      var.environment.cloud_tags,
      {
        managed-by = "facets"
        intent     = var.instance.kind
        flavor     = var.instance.flavor
        replica-of = google_sql_database_instance.mysql_instance.name
      }
    )
  }

  # Comprehensive lifecycle management for replicas to prevent stale data errors and handle imports
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      name,                          # Ignore name changes for imported resources
      database_version,              # Ignore version changes for imported resources
      region,                        # Ignore region changes for imported resources
      master_instance_name,          # Ignore master instance changes for imported resources
      settings[0].disk_size,         # Allow auto-resize to work
      settings[0].disk_type,         # Ignore disk type changes for imported resources
      settings[0].user_labels,       # Ignore label changes
      settings[0].tier,              # Ignore tier changes
      settings[0].availability_type, # Ignore availability changes
      settings[0].ip_configuration,  # Ignore IP configuration changes
      replica_configuration,         # Ignore replica configuration changes
    ]
  }
}