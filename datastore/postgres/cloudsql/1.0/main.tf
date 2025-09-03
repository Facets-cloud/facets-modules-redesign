# Random password generation for database user
resource "random_password" "master_password" {
  count   = var.instance.spec.restore_config.restore_from_backup ? 0 : 1
  length  = 16
  special = true
}

# Cloud SQL Database Instance
resource "google_sql_database_instance" "main" {
  name             = local.instance_identifier
  database_version = "POSTGRES_${var.instance.spec.version_config.version}"
  region           = var.inputs.network.attributes.region
  project          = var.inputs.gcp_provider.attributes.project

  # Deletion protection disabled for easy cleanup
  deletion_protection = false

  settings {
    tier = var.instance.spec.sizing.tier

    # Disk configuration
    disk_type             = "PD_SSD"
    disk_size             = var.instance.spec.sizing.disk_size
    disk_autoresize       = true
    disk_autoresize_limit = var.instance.spec.sizing.disk_size * 2

    # Availability configuration - always enable HA
    availability_type = "REGIONAL"

    # Backup configuration - secure defaults
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

    # Network configuration
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.inputs.network.attributes.vpc_id
      enable_private_path_for_google_cloud_services = true
    }

    # Minimal database flags to avoid conflicts
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    # User labels for resource management
    user_labels = merge(
      var.environment.cloud_tags,
      {
        managed_by = "facets"
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

  # Handle restore from backup scenario
  dynamic "restore_backup_context" {
    for_each = var.instance.spec.restore_config.restore_from_backup ? [1] : []
    content {
      backup_run_id = var.instance.spec.restore_config.source_instance_id
    }
  }
}

# Default database creation
resource "google_sql_database" "default" {
  name     = var.instance.spec.version_config.database_name
  instance = google_sql_database_instance.main.name
  project  = var.inputs.gcp_provider.attributes.project
}

# Master user creation
resource "google_sql_user" "master_user" {
  name     = var.instance.spec.restore_config.restore_from_backup ? var.instance.spec.restore_config.master_username : "postgres"
  instance = google_sql_database_instance.main.name
  password = local.master_password
  project  = var.inputs.gcp_provider.attributes.project
}

# Read replicas (if requested)
resource "google_sql_database_instance" "read_replica" {
  count                = var.instance.spec.sizing.read_replica_count
  name                 = "${var.instance_name}-${var.environment.unique_name}-replica-${count.index + 1}"
  master_instance_name = google_sql_database_instance.main.name
  region               = var.inputs.network.attributes.region
  database_version     = "POSTGRES_${var.instance.spec.version_config.version}"
  project              = var.inputs.gcp_provider.attributes.project
  deletion_protection  = false

  replica_configuration {
    failover_target = false
  }

  settings {
    tier = var.instance.spec.sizing.tier

    # Disk configuration
    disk_type       = "PD_SSD"
    disk_autoresize = true

    # Availability configuration
    availability_type = "ZONAL"

    # Network configuration
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.inputs.network.attributes.vpc_id
      enable_private_path_for_google_cloud_services = true
    }

    # User labels for resource management
    user_labels = merge(
      var.environment.cloud_tags,
      {
        managed_by = "facets"
        intent     = var.instance.kind
        flavor     = var.instance.flavor
        replica    = "true"
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