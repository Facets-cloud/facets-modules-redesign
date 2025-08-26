# Local computations for PostgreSQL on Kubernetes
locals {
  # Naming and resource identifiers
  postgres_name = "${var.instance_name}-${var.environment.unique_name}"
  namespace     = var.instance.spec.imports != null ? lookup(var.instance.spec.imports, "namespace", "default") : "default"

  # Helm release configuration
  helm_release_name = var.instance.spec.imports != null ? lookup(var.instance.spec.imports, "helm_release_name", local.postgres_name) : local.postgres_name

  # PostgreSQL configuration
  postgres_version = lookup(var.instance.spec.version_config, "version", "16")
  database_name    = lookup(var.instance.spec.version_config, "database_name", "postgres")
  master_username  = lookup(var.instance.spec.version_config, "username", "postgres")

  # Architecture and replica configuration
  architecture       = lookup(var.instance.spec.sizing, "architecture", "standalone")
  enable_replication = lookup(var.instance.spec.sizing, "architecture", "standalone") == "replication"
  read_replica_count = local.enable_replication ? lookup(var.instance.spec.sizing, "read_replica_count", 0) : 0

  # Storage configuration
  storage_size  = var.instance.spec.sizing.storage.size
  storage_class = lookup(var.instance.spec.sizing.storage, "storage_class", "") != "" ? lookup(var.instance.spec.sizing.storage, "storage_class", "") : null

  # Resource configuration
  primary_resources = {
    cpu          = lookup(var.instance.spec.sizing.primary_resources, "cpu", "250m")
    memory       = lookup(var.instance.spec.sizing.primary_resources, "memory", "256Mi")
    cpu_limit    = lookup(var.instance.spec.sizing.primary_resources, "cpu_limit", "1000m")
    memory_limit = lookup(var.instance.spec.sizing.primary_resources, "memory_limit", "1Gi")
  }

  # Restore configuration
  restore_from_backup = var.instance.spec.restore_config != null ? lookup(var.instance.spec.restore_config, "restore_from_backup", false) : false
  restore_password    = var.instance.spec.restore_config != null ? lookup(var.instance.spec.restore_config, "master_password", null) : null

  # Generate random password if not restoring from backup
  master_password = local.restore_from_backup ? local.restore_password : random_password.postgres_password.result

  # Service names
  primary_service_name = "${local.helm_release_name}-postgresql"
  replica_service_name = "${local.helm_release_name}-postgresql-read"
  secret_name          = "${local.helm_release_name}-postgresql"

  # Port configuration
  postgres_port = 5432

  # Helm values for PostgreSQL - base configuration
  postgres_values_base = {
    # Image configuration
    image = {
      tag = local.postgres_version
    }

    # Authentication configuration
    auth = {
      username       = local.master_username
      password       = local.master_password
      database       = local.database_name
      existingSecret = local.restore_from_backup && var.instance.spec.imports != null ? lookup(var.instance.spec.imports, "secret_name", "") : ""
    }

    # Architecture configuration
    architecture = local.architecture

    # Primary configuration
    primary = {
      name = "primary"
      resources = {
        requests = {
          cpu    = local.primary_resources.cpu
          memory = local.primary_resources.memory
        }
        limits = {
          cpu    = local.primary_resources.cpu_limit
          memory = local.primary_resources.memory_limit
        }
      }
      persistence = {
        enabled      = true
        size         = local.storage_size
        storageClass = local.storage_class
      }
    }

    # Backup configuration (automatic, 7-day retention)
    backup = {
      enabled = true
      cronjob = {
        schedule = "0 2 * * *" # Daily at 2 AM
        storage = {
          size = local.storage_size
        }
      }
    }

    # Security defaults
    networkPolicy = {
      enabled = true
    }

    # Metrics and monitoring (hardcoded for production readiness)
    metrics = {
      enabled = true
      serviceMonitor = {
        enabled = true
      }
    }
  }

  # Read replica configuration (only when replication is enabled)
  postgres_replica_config = local.enable_replication ? {
    readReplicas = {
      name         = "read"
      replicaCount = local.read_replica_count
      resources = {
        requests = {
          cpu    = local.primary_resources.cpu
          memory = local.primary_resources.memory
        }
        limits = {
          cpu    = local.primary_resources.cpu_limit
          memory = local.primary_resources.memory_limit
        }
      }
      persistence = {
        enabled      = true
        size         = local.storage_size
        storageClass = local.storage_class
      }
    }
  } : {}

  # Final Helm values - merge base with replica config if needed
  postgres_values = merge(local.postgres_values_base, local.postgres_replica_config)
}