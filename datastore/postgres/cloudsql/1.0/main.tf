# Use existing private services connection from network module
# No need to create new private IP range or service networking connection
# The network module already provides these resources

# Random password for PostgreSQL user (when not restoring from backup)
resource "random_password" "postgres_password" {
  count   = var.instance.spec.restore_config.restore_from_backup ? 0 : 1
  length  = 16
  special = true
}

# CloudSQL PostgreSQL instance
# NOTE: Read replicas must be deleted before the master instance can be deleted
resource "google_sql_database_instance" "postgres_instance" {
  name                = local.instance_identifier
  database_version    = "POSTGRES_${var.instance.spec.version_config.version}"
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
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
      location = var.inputs.network.attributes.region
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
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
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

  # Comprehensive lifecycle management to prevent stale data errors
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      settings[0].disk_size,             # Allow auto-resize to work
      settings[0].disk_autoresize_limit, # Ignore autoresize limit changes
      settings[0].database_flags,        # Ignore database flag changes
      settings[0].user_labels,           # Ignore label changes
      settings[0].availability_type,     # Ignore availability changes
      settings[0].tier,                  # Ignore tier changes
      settings[0].backup_configuration,  # Ignore backup config changes
      settings[0].ip_configuration,      # Ignore IP configuration changes
      deletion_protection,               # Ignore deletion protection changes
    ]
  }
}

# Initial database
resource "google_sql_database" "initial_database" {
  name     = var.instance.spec.version_config.database_name
  instance = google_sql_database_instance.postgres_instance.name
}

# PostgreSQL user configuration
resource "google_sql_user" "postgres_user" {
  name     = var.instance.spec.restore_config.restore_from_backup ? var.instance.spec.restore_config.master_username : "postgres"
  instance = google_sql_database_instance.postgres_instance.name
  password = var.instance.spec.restore_config.restore_from_backup ? var.instance.spec.restore_config.master_password : random_password.postgres_password[0].result
}

# Read replicas (if specified)
resource "google_sql_database_instance" "read_replica" {
  count                = var.instance.spec.sizing.read_replica_count
  name                 = "${local.instance_identifier}-replica-${count.index + 1}"
  database_version     = google_sql_database_instance.postgres_instance.database_version
  region               = var.inputs.network.attributes.region
  master_instance_name = google_sql_database_instance.postgres_instance.name
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
        replica-of = google_sql_database_instance.postgres_instance.name
      }
    )
  }

  # Comprehensive lifecycle management for replicas to prevent stale data errors
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      settings[0].disk_size,         # Allow auto-resize to work
      settings[0].user_labels,       # Ignore label changes
      settings[0].tier,              # Ignore tier changes
      settings[0].availability_type, # Ignore availability changes
      settings[0].ip_configuration,  # Ignore IP configuration changes
      deletion_protection,           # Ignore deletion protection changes
    ]
  }
}