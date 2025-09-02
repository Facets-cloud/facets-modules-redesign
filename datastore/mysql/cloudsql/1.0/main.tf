# Private IP range for CloudSQL
resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.instance_name}-${var.environment.unique_name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.inputs.network.attributes.vpc_self_link
}

# Private services connection for CloudSQL
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.inputs.network.attributes.vpc_self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# Random password for MySQL root user (when not restoring from backup)
resource "random_password" "mysql_password" {
  count   = var.instance.spec.restore_config.restore_from_backup ? 0 : 1
  length  = 16
  special = true
}

# CloudSQL MySQL instance
resource "google_sql_database_instance" "mysql_instance" {
  name                = "${var.instance_name}-${var.environment.unique_name}"
  database_version    = "MYSQL_${replace(var.instance.spec.version_config.version, ".", "_")}"
  region              = var.inputs.network.attributes.region
  deletion_protection = false

  # Ensure private connection is established before creating instance
  depends_on = [google_service_networking_connection.private_vpc_connection]

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

    # IP configuration for private networking
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.inputs.network.attributes.vpc_self_link
      enable_private_path_for_google_cloud_services = true
      allocated_ip_range                            = null
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

  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      settings[0].disk_size
    ]
  }
}

# Initial database
resource "google_sql_database" "initial_database" {
  name     = var.instance.spec.version_config.database_name
  instance = google_sql_database_instance.mysql_instance.name
}

# Root user configuration
resource "google_sql_user" "mysql_root_user" {
  name     = var.instance.spec.restore_config.restore_from_backup ? var.instance.spec.restore_config.master_username : "root"
  instance = google_sql_database_instance.mysql_instance.name
  password = var.instance.spec.restore_config.restore_from_backup ? var.instance.spec.restore_config.master_password : random_password.mysql_password[0].result
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

    # IP configuration matching master
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.inputs.network.attributes.vpc_self_link
      enable_private_path_for_google_cloud_services = true
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

  lifecycle {
    prevent_destroy = false
  }
}