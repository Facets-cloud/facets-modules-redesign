locals {

  loki_alerts_cm = {
    for k, v in try(var.inputs.all_loki_alerting_rules_outputs, {}) : k => v["attributes"]
  }

  loki_recordings_cm = {
    for k, v in try(var.inputs.all_loki_recording_rules_outputs, {}) : k => v["attributes"]
  }

  default_loki = {
    loki = {
      podLabels = {
        resourceName = local.instance_name
        resourceType = "log_collector"
      }
      annotations = local.annotations,
      podAnnotations = local.annotations
      structuredConfig = {
        ruler = [{
          wal = {
            dir = "/var/loki/ruler-wal"
          }
          storage = {
            type = "local"
            local = {
              directory = "/var/loki/raw-rules"
            }
          }
          rule_path        = "/var/loki/processed-rules"
          alertmanager_url = "http://prometheus-operator-alertmanager.default.svc.cluster.local:9093"
          remote_write = {
            enabled = true
            client = {
              url = "http://prometheus-operator-prometheus.default.svc.cluster.local:9090/api/v1/write"
            }
          }
          ring = {
            kvstore = {
              store = "inmemory"
            }
          }
          enable_api             = true
          enable_alertmanager_v2 = true
        }, {}][length(local.loki_alerts_cm) > 0 || length(local.loki_recordings_cm) > 0 ? 0 : 1]
        server = {
          grpc_server_max_concurrent_streams = 1000
          grpc_server_max_recv_msg_size      = 41943040
          grpc_server_max_send_msg_size      = 41943040
          http_server_read_timeout           = "310s"
          http_server_write_timeout          = "310s"
          http_server_idle_timeout           = "300s"
          graceful_shutdown_timeout          = "300s"
        }
        ingester = {
          chunk_target_size    = 1572864
          chunk_encoding       = "snappy"
          max_chunk_age        = "2h"
          chunk_idle_period    = "2h"
          autoforget_unhealthy = true
        }
        schema_config = {
          configs = [
            {
              from         = "2022-06-21"
              store        = "boltdb-shipper"
              object_store = "s3"
              schema       = "v12"
              index = {
                prefix = "index_"
                period = "24h"
              }
            }
          ]
        }
        compactor = {
          working_directory   = "/data/compactor"
          shared_store        = "s3"
          compaction_interval = "10m"
        }
        querier = {
          query_timeout = "300s"
          engine = {
            timeout = "300s"
          }
        }
        ingester_client = {
          grpc_client_config = {
            max_recv_msg_size = 104857600
          }
        }
        limits_config = {
          max_global_streams_per_user = 5000
          split_queries_by_interval   = "15m"
          max_query_parallelism       = 32
        }
        storage_config = !local.is_minio_disabled ? {
          aws = {
            endpoint          = local.minio_endpoint
            access_key_id     = local.minio_username
            secret_access_key = local.minio_password
            bucketnames       = local.minio_bucket
            insecure          = true
            s3forcepathstyle  = true
            http_config = {
              response_header_timeout = "300s"
            }
          },
          boltdb_shipper = {
            shared_store = "s3"
            cache_ttl    = "48h"
          }
        } : null
      }
    }
    ruler = [{
      enabled     = true
      tolerations = local.facets_tolerations
      kind        = "Deployment"
      replicas    = 1
      extraEnv = [
        {
          name = "MY_POD_IP"
          valueFrom = {
            fieldRef = {
              fieldPath = "status.podIP"
            }
          }
        }
      ]
      extraArgs = [
        "-memberlist.bind-addr=$(MY_POD_IP)"
      ]

      extraVolumeMounts = [{
        name      = "loki-rules-volume"
        mountPath = "/var/loki/raw-rules/fake"
      }]

      extraVolumes = [{
        name = "loki-rules-volume"
        projected = {
          sources = concat([
            for k, v in local.loki_alerts_cm : {
              configMap = {
                name = v["name"]
              }
            }
            ],
            [
              for k, v in local.loki_recordings_cm : {
                configMap = {
                  name = v["name"]
                }
              }
            ]
          )
        }
      }]
    }, {}][length(local.loki_alerts_cm) > 0 || length(local.loki_recordings_cm) > 0 ? 0 : 1]
    compactor = {
      enabled     = true
      tolerations = local.facets_tolerations
      resources = {
        requests = {
          memory = "300Mi"
          cpu    = "300m"
        }
        limits = {
          memory = "1000Mi"
          cpu    = "1000m"
        }
      }
      extraEnv = [
        {
          name = "MY_POD_IP"
          valueFrom = {
            fieldRef = {
              fieldPath = "status.podIP"
            }
          }
        }
      ]
      extraArgs = [
        "-memberlist.bind-addr=$(MY_POD_IP)"
      ]
    }
    distributor = {
      replicas    = 1
      tolerations = local.facets_tolerations
      resources = {
        requests = {
          memory = "300Mi"
          cpu    = "300m"
        }
        limits = {
          memory = "1000Mi"
          cpu    = "1000m"
        }
      }
      autoscaling = {
        enabled                           = true
        minReplicas                       = 1
        maxReplicas                       = 5
        targetCPUUtilizationPercentage    = 60
        targetMemoryUtilizationPercentage = 80
      }
      extraEnv = [
        {
          name = "MY_POD_IP"
          valueFrom = {
            fieldRef = {
              fieldPath = "status.podIP"
            }
          }
        }
      ]
      extraArgs = [
        "-memberlist.bind-addr=$(MY_POD_IP)"
      ]
    }
    ingester = {
      replicas    = 1
      tolerations = local.facets_tolerations
      persistence = {
        enabled = true
        size    = "5Gi"
      }
      resources = {
        requests = {
          memory = "500Mi"
          cpu    = "300m"
        }
        limits = {
          memory = "4000Mi"
          cpu    = "1000m"
        }
      }
      autoscaling = {
        enabled                           = true
        minReplicas                       = 3
        maxReplicas                       = 5
        targetCPUUtilizationPercentage    = 60
        targetMemoryUtilizationPercentage = 80
      }
      extraEnv = [
        {
          name = "MY_POD_IP"
          valueFrom = {
            fieldRef = {
              fieldPath = "status.podIP"
            }
          }
        }
      ]
      extraArgs = [
        "-memberlist.bind-addr=$(MY_POD_IP)"
      ]
      affinity = ""
    }
    querier = {
      tolerations = local.facets_tolerations
      replicas    = 1
      persistence = {
        enabled = true
        size    = "5Gi"
      }
      resources = {
        requests = {
          memory = "300Mi"
          cpu    = "300m"
        }
        limits = {
          memory = "4000Mi"
          cpu    = "1000m"
        }
      }
      autoscaling = {
        enabled                           = true
        minReplicas                       = 1
        maxReplicas                       = 10
        targetCPUUtilizationPercentage    = 60
        targetMemoryUtilizationPercentage = 80
      }
      extraEnv = [
        {
          name = "MY_POD_IP"
          valueFrom = {
            fieldRef = {
              fieldPath = "status.podIP"
            }
          }
        }
      ]
      extraArgs = [
        "-memberlist.bind-addr=$(MY_POD_IP)"
      ]
      affinity = ""
    }
    queryFrontend = {
      tolerations = local.facets_tolerations
      replicas    = 1
      resources = {
        requests = {
          memory = "300Mi"
          cpu    = "300m"
        }
        limits = {
          memory = "1000Mi"
          cpu    = "1000m"
        }
      }
      autoscaling = {
        enabled                           = true
        minReplicas                       = 1
        maxReplicas                       = 5
        targetCPUUtilizationPercentage    = 60
        targetMemoryUtilizationPercentage = 80
      }
      extraEnv = [
        {
          name = "MY_POD_IP"
          valueFrom = {
            fieldRef = {
              fieldPath = "status.podIP"
            }
          }
        }
      ]
      extraArgs = [
        "-memberlist.bind-addr=$(MY_POD_IP)"
      ]
    }

    gateway = {
      tolerations = local.facets_tolerations
      nginxConfig = {
        httpSnippet = "proxy_read_timeout 300;\nproxy_connect_timeout 300;\nproxy_send_timeout 300;"
      }
      resources = {
        requests = {
          memory = "300Mi"
          cpu    = "300m"
        }
        limits = {
          memory = "1000Mi"
          cpu    = "1000m"
        }
      }
      "service" = {
        "type" = lookup(local.loki, "enable_vm_scrape", false) ? "LoadBalancer" : "ClusterIP"
      }
    }

    serviceMonitor = {
      enabled = true
    }
  }
}
