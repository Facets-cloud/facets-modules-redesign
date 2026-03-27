locals {
  # ── Ingester sizing ───────────────────────────────────────────────────────────
  ingester_spec      = lookup(local.loki_size, "ingester", {})
  ingester_replicas  = lookup(local.ingester_spec, "replicas", 1)
  ingester_resources = lookup(local.ingester_spec, "resources", {})
  ingester_requests  = lookup(local.ingester_resources, "requests", {})
  ingester_limits    = lookup(local.ingester_resources, "limits", {})

  # ── Querier sizing ────────────────────────────────────────────────────────────
  querier_spec      = lookup(local.loki_size, "querier", {})
  querier_replicas  = lookup(local.querier_spec, "replicas", 1)
  querier_resources = lookup(local.querier_spec, "resources", {})
  querier_requests  = lookup(local.querier_resources, "requests", {})
  querier_limits    = lookup(local.querier_resources, "limits", {})

  # ── Distributor sizing ────────────────────────────────────────────────────────
  distributor_spec      = lookup(local.loki_size, "distributor", {})
  distributor_replicas  = lookup(local.distributor_spec, "replicas", 1)
  distributor_resources = lookup(local.distributor_spec, "resources", {})
  distributor_requests  = lookup(local.distributor_resources, "requests", {})
  distributor_limits    = lookup(local.distributor_resources, "limits", {})

  # ── Storage backend config ────────────────────────────────────────────────────
  # tsdb_shipper is shared between S3 and MinIO backends
  loki_tsdb_shipper = {
    active_index_directory = "/var/loki/index"
    cache_location         = "/var/loki/index_cache"
    shared_store           = "aws"
  }

  loki_storage_config = merge(
    local.is_s3_enabled ? {
      aws = {
        bucketnames       = local.s3_bucket
        region            = local.s3_region
        # empty strings signal Loki to use IAM role / IRSA (documented behaviour)
        access_key_id     = local.s3_access_key
        secret_access_key = local.s3_secret_key
      }
    } : {
      aws = {
        # endpoint format required for S3-compatible (MinIO) backends
        endpoint          = "http://${local.minio_endpoint}"
        bucketnames       = local.minio_bucket
        region            = "us-east-1"
        access_key_id     = local.minio_access_key
        secret_access_key = local.minio_secret_key
        s3forcepathstyle  = true
      }
    },
    {
      tsdb_shipper = local.loki_tsdb_shipper
    }
  )

  # ── Schema config (tsdb + v13 — current recommended standard) ─────────────────
  loki_schema_config = {
    configs = [
      {
        from         = "2024-01-01"
        store        = "tsdb"
        object_store = "aws"
        schema       = "v13"
        index = {
          prefix = "index_"
          period = "24h"
        }
      }
    ]
  }

  # ── Constructed default Loki values ──────────────────────────────────────────
  constructed_loki_values = {
    fullnameOverride = "${var.instance_name}-loki"

    loki = {
      structuredConfig = {
        auth_enabled = local.auth_enabled

        ingester = {
          chunk_idle_period   = "1h"
          chunk_block_size    = 262144
          # chunk_retain_period must be >= chunk_idle_period to prevent data loss on restart
          chunk_retain_period = "2h"
          wal = {
            enabled               = true
            dir                   = "/var/loki/wal"
            replay_memory_ceiling = "500MB"
          }
          lifecycler = {
            ring = {
              kvstore = {
                store = "memberlist"
              }
              replication_factor = local.replication_factor
            }
          }
        }

        limits_config = {
          retention_period           = "${local.log_retention_days * 24}h"
          enforce_metric_name        = false
          reject_old_samples         = true
          reject_old_samples_max_age = "168h"
          ingestion_rate_mb          = 16
          ingestion_burst_size_mb    = 32
        }

        schema_config  = local.loki_schema_config
        storage_config = local.loki_storage_config

        compactor = {
          working_directory      = "/var/loki/compactor"
          shared_store           = "aws"
          compaction_interval    = "10m"
          retention_enabled      = true
          retention_delete_delay = "2h"
          delete_request_store   = "aws"
        }

        distributor = {
          ring = {
            kvstore = {
              store = "memberlist"
            }
          }
        }

        querier = {
          max_concurrent = 4
        }

        query_range = {
          align_queries_with_step = true
          max_retries             = 5
        }
      }
    }

    ingester = {
      replicas     = local.ingester_replicas
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
      resources = {
        requests = {
          cpu    = lookup(local.ingester_requests, "cpu", "500m")
          memory = lookup(local.ingester_requests, "memory", "1Gi")
        }
        limits = {
          cpu    = lookup(local.ingester_limits, "cpu", "1")
          memory = lookup(local.ingester_limits, "memory", "2Gi")
        }
      }
      persistence = {
        enabled      = true
        size         = "10Gi"
        storageClass = null
      }
    }

    distributor = {
      replicas     = local.distributor_replicas
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
      resources = {
        requests = {
          cpu    = lookup(local.distributor_requests, "cpu", "200m")
          memory = lookup(local.distributor_requests, "memory", "256Mi")
        }
        limits = {
          cpu    = lookup(local.distributor_limits, "cpu", "500m")
          memory = lookup(local.distributor_limits, "memory", "512Mi")
        }
      }
    }

    querier = {
      replicas     = local.querier_replicas
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
      resources = {
        requests = {
          cpu    = lookup(local.querier_requests, "cpu", "200m")
          memory = lookup(local.querier_requests, "memory", "512Mi")
        }
        limits = {
          cpu    = lookup(local.querier_limits, "cpu", "500m")
          memory = lookup(local.querier_limits, "memory", "1Gi")
        }
      }
    }

    queryFrontend = {
      replicas     = 1
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    }

    tableManager = {
      enabled = false
    }

    gateway = {
      enabled      = true
      replicas     = 1
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    }

    serviceMonitor = {
      enabled = local.prometheus_enabled
    }
  }
}
