terraform {
  required_version = ">= 1.0"
}

resource "google_project_service" "memorystore" {
  project            = local.project_id
  service            = "memorystore.googleapis.com"
  disable_on_destroy = false
}

resource "google_memorystore_instance" "main" {
  instance_id = local.instance_id
  project     = local.project_id
  location    = local.region

  mode           = local.mode_normalized
  engine_version = lookup(var.instance.spec.version_config, "engine_version", "VALKEY_7_2")
  shard_count    = lookup(var.instance.spec.sizing, "shard_count", 1)
  replica_count  = lookup(var.instance.spec.sizing, "replica_count", 0)
  node_type      = lookup(var.instance.spec.sizing, "node_type", "SHARED_CORE_NANO")

  transit_encryption_mode     = local.enable_tls ? "SERVER_AUTHENTICATION" : "TRANSIT_ENCRYPTION_DISABLED"
  authorization_mode          = local.authorization_mode
  deletion_protection_enabled = false

  desired_auto_created_endpoints {
    network    = local.network
    project_id = local.project_id
  }

  # `databases` is CLUSTER_DISABLED-only; sending it on a cluster instance is a
  # 400 from the Memorystore API. Drop the key rather than set it to "1".
  engine_configs = merge(
    {
      maxmemory-policy = lookup(var.instance.spec.engine_config, "maxmemory_policy", "volatile-lru")
    },
    local.is_cluster_enabled ? {} : {
      databases = tostring(local.database_count)
    }
  )

  # Optional block: when backups are disabled it must be ABSENT entirely. The API
  # rejects an automated_backup_config that carries no retention, so an empty
  # block is not the same as no block.
  dynamic "automated_backup_config" {
    for_each = local.backup_enabled ? [1] : []
    content {
      retention = "${local.backup_retention_days * 86400}s"
      fixed_frequency_schedule {
        start_time {
          hours = local.backup_start_hour
        }
      }
    }
  }

  maintenance_policy {
    weekly_maintenance_window {
      day = var.instance.spec.maintenance.day
      start_time {
        hours   = var.instance.spec.maintenance.hour
        minutes = var.instance.spec.maintenance.minute
        seconds = 0
        nanos   = 0
      }
    }
  }

  labels = merge(
    var.environment.cloud_tags,
    {
      managed-by    = "facets"
      instance-name = var.instance_name
      environment   = var.environment.name
      intent        = "redis"
      flavor        = "gcp-valkey"
      psc-policy    = local.psc_policy_label
    }
  )

  depends_on = [google_project_service.memorystore]
}
