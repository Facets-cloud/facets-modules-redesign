locals {
  spec     = lookup(var.instance, "spec", {})
  metadata = lookup(local.spec, "metadata", {})

  # ── Namespace ─────────────────────────────────────────────────────────────
  namespace = lookup(local.metadata, "namespace", "facets")

  # ── GCP / GCS from inputs ─────────────────────────────────────────────────
  project     = var.inputs.cloud_account.attributes.project_id
  bucket_name = var.inputs.storage.attributes.bucket_name

  # ── Loki spec ─────────────────────────────────────────────────────────────
  loki_spec                = lookup(local.spec, "loki", {})
  loki_chart_version       = lookup(local.loki_spec, "chart_version", "6.55.0")
  loki_deployment_mode     = lookup(local.loki_spec, "deployment_mode", "SingleBinary")
  loki_retention_hours     = lookup(local.loki_spec, "retention_hours", 720)
  loki_chunks_cache_memory = lookup(local.loki_spec, "chunks_cache_memory_mb", 1024)
  loki_size                = lookup(local.loki_spec, "size", {})

  # Per-component resource lookups
  loki_distributor_resources = lookup(lookup(local.loki_size, "distributor", {}), "resources", {})
  loki_distributor_requests  = lookup(local.loki_distributor_resources, "requests", {})
  loki_distributor_limits    = lookup(local.loki_distributor_resources, "limits", {})

  loki_ingester_resources = lookup(lookup(local.loki_size, "ingester", {}), "resources", {})
  loki_ingester_requests  = lookup(local.loki_ingester_resources, "requests", {})
  loki_ingester_limits    = lookup(local.loki_ingester_resources, "limits", {})

  loki_querier_resources = lookup(lookup(local.loki_size, "querier", {}), "resources", {})
  loki_querier_requests  = lookup(local.loki_querier_resources, "requests", {})
  loki_querier_limits    = lookup(local.loki_querier_resources, "limits", {})

  loki_query_frontend_resources = lookup(lookup(local.loki_size, "queryFrontend", {}), "resources", {})
  loki_query_frontend_requests  = lookup(local.loki_query_frontend_resources, "requests", {})
  loki_query_frontend_limits    = lookup(local.loki_query_frontend_resources, "limits", {})

  loki_compactor_resources = lookup(lookup(local.loki_size, "compactor", {}), "resources", {})
  loki_compactor_requests  = lookup(local.loki_compactor_resources, "requests", {})
  loki_compactor_limits    = lookup(local.loki_compactor_resources, "limits", {})

  loki_index_gateway_resources = lookup(lookup(local.loki_size, "indexGateway", {}), "resources", {})
  loki_index_gateway_requests  = lookup(local.loki_index_gateway_resources, "requests", {})
  loki_index_gateway_limits    = lookup(local.loki_index_gateway_resources, "limits", {})

  loki_gateway_resources = lookup(lookup(local.loki_size, "gateway", {}), "resources", {})
  loki_gateway_requests  = lookup(local.loki_gateway_resources, "requests", {})
  loki_gateway_limits    = lookup(local.loki_gateway_resources, "limits", {})

  loki_query_scheduler_resources = lookup(lookup(local.loki_size, "queryScheduler", {}), "resources", {})
  loki_query_scheduler_requests  = lookup(local.loki_query_scheduler_resources, "requests", {})
  loki_query_scheduler_limits    = lookup(local.loki_query_scheduler_resources, "limits", {})
  loki_user_values               = lookup(local.loki_spec, "values", {})

  # SingleBinary
  is_single_binary    = local.loki_deployment_mode == "SingleBinary"
  loki_sb_size        = lookup(local.loki_spec, "single_binary_size", {})
  loki_sb_resources   = lookup(local.loki_sb_size, "resources", {})
  loki_sb_requests    = lookup(local.loki_sb_resources, "requests", {})
  loki_sb_limits      = lookup(local.loki_sb_resources, "limits", {})
  loki_sb_persistence = lookup(local.loki_sb_size, "persistence_size", "20Gi")

  # ── Promtail spec ─────────────────────────────────────────────────────────
  promtail_spec          = lookup(local.spec, "promtail", {})
  promtail_enabled       = lookup(local.promtail_spec, "enabled", true)
  promtail_chart_version = lookup(local.promtail_spec, "chart_version", "6.17.1")
  promtail_size          = lookup(local.promtail_spec, "size", {})
  promtail_resources     = lookup(local.promtail_size, "resources", {})
  promtail_requests      = lookup(local.promtail_resources, "requests", {})
  promtail_limits        = lookup(local.promtail_resources, "limits", {})
  promtail_user_values   = lookup(local.promtail_spec, "values", {})

  # ── Loki Canary spec — now controlled via unified chart lokiCanary.enabled ──
  loki_canary_spec    = lookup(local.spec, "loki_canary", {})
  loki_canary_enabled = lookup(local.loki_canary_spec, "enabled", false)

  # ── Node placement from node pool input ───────────────────────────────────
  nodepool_taints = try(var.inputs.kubernetes_node_pool_details.attributes.taints, [])
  node_selector   = try(var.inputs.kubernetes_node_pool_details.attributes.node_selector, {})

  # Build explicit tolerations with operator=Equal from nodepool taints
  tolerations = [for t in local.nodepool_taints : {
    key      = t.key
    operator = "Equal"
    value    = t.value
    effect   = t.effect
  }]

  # ── Service account name (max 28 chars for GCP) ───────────────────────────
  env_name = lookup(var.environment, "name", "default")
  sa_name  = substr(replace("loki-${var.instance_name}-${local.env_name}", "_", "-"), 0, 28)

  # ── Loki gateway endpoint (internal k8s service) ──────────────────────────
  # SingleBinary: direct to loki service on port 3100
  # Distributed: via gateway service on port 80
  loki_endpoint = local.is_single_binary ? "${var.instance_name}.${local.namespace}.svc.cluster.local:3100" : "${var.instance_name}-gateway.${local.namespace}.svc.cluster.local"

  # ── Default Loki Helm values (unified grafana/loki chart, GCS backend) ────
  default_loki_values = {
    deploymentMode = local.loki_deployment_mode

    # Workload Identity annotation at root serviceAccount level
    serviceAccount = {
      create = true
      annotations = {
        "iam.gke.io/gcp-service-account" = google_service_account.loki_gcs.email
      }
    }

    loki = {
      auth_enabled = false

      podLabels = {
        resourceName = var.instance_name
        resourceType = "log_collector"
      }

      # GCS storage backend
      storage = {
        type = "gcs"
        bucketNames = {
          chunks = local.bucket_name
          ruler  = local.bucket_name
          admin  = local.bucket_name
        }
        gcs = {
          chunkBufferSize = 0
          requestTimeout  = "0s"
          enableHttp2     = true
        }
      }

      # Modern v13/tsdb schema (Loki 3.x)
      schemaConfig = {
        configs = [
          {
            from         = "2024-04-01"
            store        = "tsdb"
            object_store = "gcs"
            schema       = "v13"
            index = {
              prefix = "index_"
              period = "24h"
            }
          }
        ]
      }

      # Ingester chunking
      ingester = {
        chunk_target_size    = 1572864
        chunk_encoding       = "snappy"
        max_chunk_age        = "2h"
        chunk_idle_period    = "2h"
        autoforget_unhealthy = true
      }

      ingester_client = {
        grpc_client_config = {
          max_recv_msg_size = 104857600
        }
      }

      # Server tuning
      server = {
        grpc_server_max_concurrent_streams = 1000
        grpc_server_max_recv_msg_size      = 41943040
        grpc_server_max_send_msg_size      = 41943040
        http_server_read_timeout           = "310s"
        http_server_write_timeout          = "310s"
        http_server_idle_timeout           = "300s"
        graceful_shutdown_timeout          = "300s"
      }

      # Limits
      limits_config = {
        reject_old_samples            = true
        reject_old_samples_max_age    = "168h"
        max_cache_freshness_per_query = "10m"
        split_queries_by_interval     = "15m"
        query_timeout                 = "300s"
        max_global_streams_per_user   = 5000
        max_query_parallelism         = 32
        volume_enabled                = true
        retention_period              = "${local.loki_retention_hours}h"
      }

      # Compactor config
      compactor = {
        working_directory    = local.is_single_binary ? "/var/loki/compactor" : "/data/compactor"
        compaction_interval  = "10m"
        retention_enabled    = true
        delete_request_store = "gcs"
      }

      commonConfig = {
        path_prefix        = "/var/loki"
        replication_factor = local.is_single_binary ? 1 : 3
      }
    }

    # In SingleBinary mode, memberlist is not needed (single replica)
    memberlist = local.is_single_binary ? { join_members = [] } : {}

    # ── SingleBinary sizing & placement ─────────────────────────────────────
    singleBinary = {
      replicas     = local.is_single_binary ? 1 : 0
      tolerations  = local.tolerations
      nodeSelector = local.node_selector
      persistence = {
        enabled = true
        size    = local.loki_sb_persistence
      }
      resources = {
        requests = {
          cpu    = lookup(local.loki_sb_requests, "cpu", "1000m")
          memory = lookup(local.loki_sb_requests, "memory", "2Gi")
        }
        limits = {
          cpu    = lookup(local.loki_sb_limits, "cpu", "2000m")
          memory = lookup(local.loki_sb_limits, "memory", "4Gi")
        }
      }
    }

    # ── Distributed component sizing & placement ────────────────────────────
    compactor = {
      enabled      = true
      tolerations  = local.tolerations
      nodeSelector = local.node_selector
      resources = {
        requests = {
          memory = lookup(local.loki_compactor_requests, "memory", "300Mi")
          cpu    = lookup(local.loki_compactor_requests, "cpu", "300m")
        }
        limits = {
          memory = lookup(local.loki_compactor_limits, "memory", "1000Mi")
          cpu    = lookup(local.loki_compactor_limits, "cpu", "1000m")
        }
      }
    }

    distributor = {
      replicas     = local.is_single_binary ? 0 : 1
      tolerations  = local.tolerations
      nodeSelector = local.node_selector
      resources = {
        requests = {
          memory = lookup(local.loki_distributor_requests, "memory", "300Mi")
          cpu    = lookup(local.loki_distributor_requests, "cpu", "300m")
        }
        limits = {
          memory = lookup(local.loki_distributor_limits, "memory", "1000Mi")
          cpu    = lookup(local.loki_distributor_limits, "cpu", "1000m")
        }
      }
      autoscaling = {
        enabled                           = !local.is_single_binary
        minReplicas                       = 1
        maxReplicas                       = 5
        targetCPUUtilizationPercentage    = 60
        targetMemoryUtilizationPercentage = 80
      }
    }

    ingester = {
      replicas     = local.is_single_binary ? 0 : 1
      tolerations  = local.tolerations
      nodeSelector = local.node_selector
      persistence = {
        enabled = true
        size    = "5Gi"
      }
      resources = {
        requests = {
          memory = lookup(local.loki_ingester_requests, "memory", "500Mi")
          cpu    = lookup(local.loki_ingester_requests, "cpu", "300m")
        }
        limits = {
          memory = lookup(local.loki_ingester_limits, "memory", "4000Mi")
          cpu    = lookup(local.loki_ingester_limits, "cpu", "1000m")
        }
      }
      autoscaling = {
        enabled                           = !local.is_single_binary
        minReplicas                       = 1
        maxReplicas                       = 3
        targetCPUUtilizationPercentage    = 60
        targetMemoryUtilizationPercentage = 80
      }
    }

    querier = {
      replicas     = local.is_single_binary ? 0 : 1
      tolerations  = local.tolerations
      nodeSelector = local.node_selector
      persistence = {
        enabled = true
        size    = "5Gi"
      }
      resources = {
        requests = {
          memory = lookup(local.loki_querier_requests, "memory", "300Mi")
          cpu    = lookup(local.loki_querier_requests, "cpu", "300m")
        }
        limits = {
          memory = lookup(local.loki_querier_limits, "memory", "4000Mi")
          cpu    = lookup(local.loki_querier_limits, "cpu", "1000m")
        }
      }
      autoscaling = {
        enabled                           = !local.is_single_binary
        minReplicas                       = 1
        maxReplicas                       = 10
        targetCPUUtilizationPercentage    = 60
        targetMemoryUtilizationPercentage = 80
      }
    }

    queryScheduler = {
      replicas     = local.is_single_binary ? 0 : 2
      tolerations  = local.tolerations
      nodeSelector = local.node_selector
      resources = {
        requests = {
          memory = lookup(local.loki_query_scheduler_requests, "memory", "300Mi")
          cpu    = lookup(local.loki_query_scheduler_requests, "cpu", "100m")
        }
        limits = {
          memory = lookup(local.loki_query_scheduler_limits, "memory", "1000Mi")
          cpu    = lookup(local.loki_query_scheduler_limits, "cpu", "500m")
        }
      }
    }

    queryFrontend = {
      replicas     = local.is_single_binary ? 0 : 1
      tolerations  = local.tolerations
      nodeSelector = local.node_selector
      resources = {
        requests = {
          memory = lookup(local.loki_query_frontend_requests, "memory", "300Mi")
          cpu    = lookup(local.loki_query_frontend_requests, "cpu", "300m")
        }
        limits = {
          memory = lookup(local.loki_query_frontend_limits, "memory", "1000Mi")
          cpu    = lookup(local.loki_query_frontend_limits, "cpu", "1000m")
        }
      }
      autoscaling = {
        enabled                           = !local.is_single_binary
        minReplicas                       = 1
        maxReplicas                       = 5
        targetCPUUtilizationPercentage    = 60
        targetMemoryUtilizationPercentage = 80
      }
    }

    indexGateway = {
      enabled      = !local.is_single_binary
      replicas     = local.is_single_binary ? 0 : 1
      tolerations  = local.tolerations
      nodeSelector = local.node_selector
      resources = {
        requests = {
          memory = lookup(local.loki_index_gateway_requests, "memory", "300Mi")
          cpu    = lookup(local.loki_index_gateway_requests, "cpu", "300m")
        }
        limits = {
          memory = lookup(local.loki_index_gateway_limits, "memory", "1000Mi")
          cpu    = lookup(local.loki_index_gateway_limits, "cpu", "1000m")
        }
      }
    }

    gateway = {
      enabled      = !local.is_single_binary
      tolerations  = local.tolerations
      nodeSelector = local.node_selector
      resources = {
        requests = {
          memory = lookup(local.loki_gateway_requests, "memory", "300Mi")
          cpu    = lookup(local.loki_gateway_requests, "cpu", "300m")
        }
        limits = {
          memory = lookup(local.loki_gateway_limits, "memory", "1000Mi")
          cpu    = lookup(local.loki_gateway_limits, "cpu", "1000m")
        }
      }
      service = { type = "ClusterIP" }
    }

    # Chunks cache — chart default requests 9830Mi; configurable via spec.loki.chunks_cache_memory_mb
    chunksCache = {
      allocatedMemory = local.loki_chunks_cache_memory
      tolerations     = local.tolerations
      nodeSelector    = local.node_selector
      resources = {
        requests = { cpu = "100m", memory = "${local.loki_chunks_cache_memory + 256}Mi" }
        limits   = { memory = "${local.loki_chunks_cache_memory + 256}Mi" }
      }
    }

    resultsCache = {
      tolerations  = local.tolerations
      nodeSelector = local.node_selector
    }

    # Disable SimpleScalable components in Distributed/SingleBinary modes
    write   = local.loki_deployment_mode == "SimpleScalable" ? {} : { replicas = 0 }
    read    = local.loki_deployment_mode == "SimpleScalable" ? {} : { replicas = 0 }
    backend = local.loki_deployment_mode == "SimpleScalable" ? {} : { replicas = 0 }

    ruler = {
      enabled  = false
      replicas = 0
    }

    # Canary now built into unified chart
    # test.enabled must match lokiCanary.enabled — chart validate.yaml enforces this
    lokiCanary = {
      enabled = local.loki_canary_enabled
    }

    test = {
      enabled = local.loki_canary_enabled
    }

    # ServiceMonitor moved under monitoring in unified chart
    monitoring = {
      serviceMonitor = {
        enabled  = true
        interval = "15s"
      }
      dashboards = { enabled = false }
      rules      = { enabled = false }
    }
  }

  # ── Default Promtail Helm values ──────────────────────────────────────────
  default_promtail_values = {
    config = {
      clients = [
        {
          url       = "http://${local.loki_endpoint}/loki/api/v1/push"
          tenant_id = "facets"
        }
      ]
      snippets = {
        pipelineStages = [
          { cri = {} }
        ]
      }
    }
    podLabels = {
      resourceName = var.instance_name
      resourceType = "log_collector"
    }
    nodeSelector = { "kubernetes.io/os" = "linux" }
    # Wildcard toleration — promtail is a log collector DaemonSet that must run on every node
    # regardless of what taints are present (infra, jobs, keycloak, observability, critical, etc.)
    tolerations    = [{ operator = "Exists" }]
    serviceMonitor = { enabled = true }
    resources = {
      requests = {
        memory = lookup(local.promtail_requests, "memory", "100Mi")
        cpu    = lookup(local.promtail_requests, "cpu", "100m")
      }
      limits = {
        memory = lookup(local.promtail_limits, "memory", "1000Mi")
        cpu    = lookup(local.promtail_limits, "cpu", "1000m")
      }
    }
  }
}
