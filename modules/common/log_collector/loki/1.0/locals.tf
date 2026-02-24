locals {
  # Extract spec and configuration
  spec          = lookup(var.instance, "spec", {})
  metadata      = lookup(var.instance, "metadata", {})
  instance_name = lower(var.instance_name)

  # Helm configuration from spec (new pattern - no more advanced.loki.*)
  loki_helm_values     = lookup(local.spec, "loki_helm_values", {})
  promtail_helm_values = lookup(local.spec, "promtail_helm_values", {})
  minio_helm_values    = lookup(local.spec, "minio_helm_values", {})

  # Basic configuration
  loki_namespace = var.environment.namespace

  # Storage configuration - check if external storage is configured
  loki_config            = lookup(local.loki_helm_values, "loki", {})
  loki_structured_config = lookup(local.loki_config, "structuredConfig", {})
  loki_storage_config    = lookup(local.loki_config, "storageConfig", lookup(local.loki_structured_config, "storage_config", {}))
  azure_storage_config   = lookup(local.loki_storage_config, "azure", {})
  gcs_storage_config     = lookup(local.loki_storage_config, "gcs", {})
  aws_storage_config     = lookup(local.loki_storage_config, "aws", lookup(local.loki_storage_config, "s3", {}))
  is_minio_disabled      = length(local.azure_storage_config) > 0 || length(local.gcs_storage_config) > 0 || length(local.aws_storage_config) > 0

  # Minio configuration
  minio_replicas = lookup(lookup(local.minio_helm_values, "statefulset", {}), "replicaCount", 4)
  minio_username = "loki_user"
  minio_bucket   = "loki"
  minio_endpoint = "${local.instance_name}-minio.${local.loki_namespace}.svc.cluster.local:9000"

  # Loki endpoints
  loki_endpoint = "${local.instance_name}-loki-distributed-gateway.${local.loki_namespace}.svc.cluster.local"

  # Annotations
  default_annotations = {
    "facets.cloud/exclude-scale-down" = "true"
  }
  annotations = merge(local.default_annotations, lookup(local.metadata, "annotations", {}))

  # PVC configuration
  ingester_pvc_enabled = lookup(lookup(lookup(local.loki_helm_values, "ingester", {}), "persistence", {}), "enabled", true)
  querier_pvc_enabled  = lookup(lookup(lookup(local.loki_helm_values, "querier", {}), "persistence", {}), "enabled", true)
  ingester_replicas    = lookup(lookup(local.loki_helm_values, "ingester", {}), "replicas", 1)
  querier_replicas     = lookup(lookup(local.loki_helm_values, "querier", {}), "replicas", 1)
  ingester_pvc_size    = lookup(local.spec, "ingester_pvc_size", "5Gi")
  querier_pvc_size     = lookup(local.spec, "querier_pvc_size", "5Gi")

  # Grafana datasource configuration
  query_timeout  = lookup(local.spec, "loki_query_timeout", 60)
  derived_fields = values(lookup(local.spec, "derived_fields", {}))

  # Promtail configuration
  enable_default_pack  = lookup(local.spec, "enable_default_pack", true)
  is_kubelet_scrape    = lookup(local.spec, "enable_kubelet_log_scraping", false)
  scrape_extra_matches = lookup(local.spec, "kubelet_scrape_extra_matches", [])
  scrape_matches = concat([
    for scrape_extra_match in local.scrape_extra_matches : "_SYSTEMD_UNIT=${scrape_extra_match}"
    ], [
    "_SYSTEMD_UNIT=kubelet.service"
  ])

  # Tolerations
  facets_tolerations = concat(
    lookup(var.environment, "default_tolerations", [{
      key      = "kubernetes.azure.com/scalesetpriority"
      value    = "spot"
      operator = "Equal"
      effect   = "NoSchedule"
    }]),
    lookup(var.inputs.kubernetes_details.attributes, "facets_dedicated_tolerations", [])
  )

  # Route53 configuration
  record_type = lookup(var.environment, "cloud", "AWS") == "AWS" ? "CNAME" : "A"

  # ========== DEFAULT LOKI CONFIGURATION ==========
  default_loki = {
    loki = {
      podLabels = {
        resourceName = local.instance_name
        resourceType = "log_collector"
      }
      annotations    = local.annotations
      podAnnotations = local.annotations
      structuredConfig = {
        ruler = {
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
          alertmanager_url = lookup(var.inputs.prometheus, null) != null ? lookup(var.inputs.prometheus.attributes, "alertmanager_url", "http://prometheus-operator-alertmanager.default.svc.cluster.local:9093") : "http://prometheus-operator-alertmanager.default.svc.cluster.local:9093"
          remote_write = {
            enabled = true
            client = {
              url = lookup(var.inputs.prometheus, null) != null ? lookup(var.inputs.prometheus.attributes, "prometheus_url", "http://prometheus-operator-prometheus.default.svc.cluster.local:9090/api/v1/write") : "http://prometheus-operator-prometheus.default.svc.cluster.local:9090/api/v1/write"
            }
          }
          ring = {
            kvstore = {
              store = "inmemory"
            }
          }
          enable_api             = true
          enable_alertmanager_v2 = true
        }
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
            secret_access_key = random_password.minio_password[0].result
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
    ruler = {
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
    }
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
      service = {
        type = lookup(local.spec, "enable_route53_record", false) ? "LoadBalancer" : "ClusterIP"
      }
    }
    serviceMonitor = {
      enabled = true
    }
  }

  # Merge user-provided values with defaults
  constructed_loki_helm_values  = local.default_loki
  user_defined_loki_helm_values = local.loki_helm_values

  # ========== DEFAULT PROMTAIL CONFIGURATION ==========
  pipeline_stages = {
    config = {
      snippets = {
        pipelineStages = concat(
          [
            lookup(local.spec, "use_docker_parser", false) ? {
              docker = {}
              } : {
              cri = {}
            },
            {
              labeldrop = [
                "filename",
                "container",
                "pod",
                "job"
              ]
            },
            local.enable_default_pack == true ? {
              pack = {
                labels = [
                  "pod",
                  "container",
                  "job"
                ]
              }
            } : {}
          ],
          lookup(lookup(lookup(local.promtail_helm_values, "config", {}), "snippets", {}), "pipelineStages", [])
        )
      }
    }
  }

  default_promtail = {
    config = {
      clients = [
        {
          url = "http://${local.loki_endpoint}/loki/api/v1/push"
        }
      ]
      snippets = {
        extraScrapeConfigs = local.is_kubelet_scrape ? yamlencode(
          [
            {
              job_name = "journal"
              journal = {
                path    = "/var/log/journal"
                max_age = "12h"
                labels = {
                  job = "systemd-journal"
                }
                matches = join(" ", local.scrape_matches)
              }
              relabel_configs = [
                {
                  source_labels = [
                    "__journal__systemd_unit"
                  ],
                  target_label = "app"
                },
                {
                  source_labels = [
                    "__journal__hostname"
                  ],
                  target_label = "hostname"
                }
              ]
            }
          ]
        ) : ""
      }
    }
    podLabels = {
      resourceName = local.instance_name
      resourceType = "log_collector"
    }
    annotations    = local.annotations
    podAnnotations = local.annotations
    extraVolumes = local.is_kubelet_scrape ? [
      {
        name = "journal"
        hostPath = {
          path = "/var/log/journal"
        }
      }
    ] : []
    extraVolumeMounts = local.is_kubelet_scrape ? [
      {
        name      = "journal"
        mountPath = "/var/log/journal"
        readOnly  = true
      }
    ] : []
    nodeSelector = {
      "kubernetes.io/os" : "linux"
    }
    tolerations = local.facets_tolerations
    serviceMonitor = {
      enabled = true
    }
    resources = {
      requests = {
        memory = "100Mi"
        cpu    = "100m"
      }
      limits = {
        memory = "1000Mi"
        cpu    = "1000m"
      }
    }
    priorityClassName = "facets-critical"
  }

  # Merge user-provided values with defaults
  constructed_promtail_helm_values  = local.default_promtail
  user_defined_promtail_helm_values = local.promtail_helm_values

  # ========== DEFAULT MINIO CONFIGURATION ==========
  default_minio = {
    mode = "distributed"
    auth = {
      rootUser     = lookup(lookup(local.minio_helm_values, "auth", {}), "rootUser", "admin")
      rootPassword = lookup(lookup(local.minio_helm_values, "auth", {}), "rootPassword", try(random_password.minio_password[0].result, "changeme"))
    }
    tolerations = local.facets_tolerations
    image = {
      registry   = "docker.io"
      repository = "bitnamilegacy/minio"
    }
    volumePermissions = {
      image = {
        registry   = "docker.io"
        repository = "bitnamilegacy/os-shell"
        tag        = "11-debian-11-r90"
      }
    }
    provisioning = {
      enabled = true
      users = [
        {
          username = local.minio_username
          password = try(random_password.minio_password[0].result, "changeme")
          disabled = false
          policies = [
            "readwrite",
            "consoleAdmin",
            "diagnostics"
          ],
          setPolicies = false
        }
      ]
      buckets = [
        {
          name = local.minio_bucket
        }
      ]
    }
    metrics = {
      serviceMonitor = {
        enabled = true
      }
    }
    resources = {
      requests = {
        memory = "100Mi"
        cpu    = "100m"
      }
      limits = {
        memory = "1000Mi"
        cpu    = "1000m"
      }
    }
  }

  # Merge user-provided values with defaults
  constructed_minio_helm_values  = local.default_minio
  user_defined_minio_helm_values = local.minio_helm_values

  # ========== LOKI CANARY CONFIGURATION ==========
  loki_canary = merge(
    {
      lokiAddress = "${local.loki_endpoint}:80"
      serviceMonitor = {
        enabled = true
      }
    },
    lookup(local.spec, "loki_canary_helm_values", {})
  )

  # ========== OUTPUT ATTRIBUTES ==========
  output_attributes = {
    loki_endpoint   = local.loki_endpoint
    loki_namespace  = local.loki_namespace
    gateway_fqdn    = try(aws_route53_record.loki_gateway[0].fqdn, null)
    minio_endpoint  = local.is_minio_disabled ? null : local.minio_endpoint
    datasource_name = "Facets Loki"
  }

  output_interfaces = {}
}
