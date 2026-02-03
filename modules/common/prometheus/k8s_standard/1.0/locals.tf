locals {
  spec = lookup(var.instance, "spec", {})

  prometheusOperatorSpec = lookup(local.spec, "operator", {
    "enabled" = true
    "size" = {
      "resources" = {
        "requests" = {
          "cpu"    = "200m"
          "memory" = "512Mi"
        }
        "limits" = {
          "cpu"    = "200m"
          "memory" = "512Mi"
        }
      }
    }
  })

  prometheusSpec = lookup(local.spec, "prometheus", {
    "enabled" = true
    "size" = {
      "resources" = {
        "requests" = {
          "cpu"    = "1000m"
          "memory" = "4Gi"
        }
        "limits" = {
          "cpu"    = "1000m"
          "memory" = "4Gi"
        }
      }
      "volume" = "100Gi"
    }
  })

  alertmanagerSpec = lookup(local.spec, "alertmanager", {
    "enabled" = true
    "size" = {
      "resources" = {
        "requests" = {
          "cpu"    = "1000m"
          "memory" = "2Gi"
        }
        "limits" = {
          "cpu"    = "1000m"
          "memory" = "2Gi"
        }
      }
      "volume" = "10Gi"
    }
  })

  grafanaSpec = lookup(local.spec, "grafana", {
    "enabled" = false
    "size" = {
      "resources" = {
        "requests" = {
          "cpu"    = "200m"
          "memory" = "512Mi"
        }
        "limits" = {
          "cpu"    = "200m"
          "memory" = "512Mi"
        }
      }
    }
  })

  kubeStateMetricsSpec = lookup(local.spec, "kube-state-metrics", {
    "enabled" = false
    "size" = {
      "resources" = {
        "requests" = {
          "cpu"    = null
          "memory" = null
        }
        "limits" = {
          "cpu"    = null
          "memory" = null
        }
      }
    }
  })

  valuesSpec = lookup(local.spec, "values", {})

  prometheus_retention = lookup(local.spec, "retention", "100d")

  # Extract user's alertmanager config from spec.values (if provided)
  user_alertmanager_config = lookup(lookup(local.valuesSpec, "alertmanager", {}), "config", {})
  user_receivers           = lookup(local.user_alertmanager_config, "receivers", [])
  user_global              = lookup(local.user_alertmanager_config, "global", {})
  user_route               = lookup(local.user_alertmanager_config, "route", {})

  # Facets default receiver with platform webhooks - MUST ALWAYS BE PRESENT
  facets_default_receiver = {
    name = "default"
    webhook_configs = [
      {
        url           = "http://alertmanager-webhook.default/alerts"
        send_resolved = true
      },
      {
        url           = "https://${local.cc_host}/cc/v1/clusters/${var.environment.cluster_id}/alerts"
        send_resolved = true
        http_config = {
          bearer_token = local.cc_auth_token
        }
      }
    ]
  }

  # Concatenate user receivers (if any) with Facets default receiver
  # User receivers come first, then Facets default receiver
  all_receivers = concat(local.user_receivers, [local.facets_default_receiver])

  # Facets default global and route config
  facets_global = {
    resolve_timeout = "60m"
  }

  facets_route = {
    receiver        = "default"
    group_by        = ["alertname", "entity"]
    routes          = []
    group_wait      = "30s"
    group_interval  = "5m"
    repeat_interval = "6h"
  }

  # Merge user's global/route config with Facets defaults (user values take precedence)
  final_global = merge(local.facets_global, local.user_global)
  final_route  = merge(local.facets_route, local.user_route)

  # Final alertmanager config with all receivers
  alertmanager_config = {
    alertmanager = {
      config = merge(
        local.user_alertmanager_config, # Include any other user config fields
        {
          global    = local.final_global
          route     = local.final_route
          receivers = local.all_receivers # User receivers + Facets default
        }
      )
    }
  }

  # Nodepool configuration from inputs (encode/decode pattern)
  # Decode back into object
  nodepool_config      = lookup(var.inputs, "kubernetes_node_pool_details", null)
  nodepool_tolerations = lookup(local.nodepool_config, "taints", [])
  nodepool_labels      = lookup(local.nodepool_config, "node_selector", {})

  # Use only nodepool configuration (no fallbacks)
  tolerations  = local.nodepool_tolerations
  nodeSelector = local.nodepool_labels
  namespace    = lookup(local.spec, "namespace", var.environment.namespace)

  # Default values for the helm chart
  default_values = {
    fullnameOverride                   = module.name.name
    cleanPrometheusOperatorObjectNames = true
    crds = {
      enabled = lookup(local.spec, "enable_crds", true)
      upgradeJob = {
        enabled = lookup(local.spec, "upgrade_job", false)
      }
    }
    defaultRules = {
      create = false
    }
    prometheusOperator = {
      enabled = lookup(local.prometheusOperatorSpec, "enabled", true)
      tls = {
        enabled = false
      }
      admissionWebhooks = {
        enabled = false
      }
      resources = {
        requests = {
          cpu    = lookup(local.prometheusOperatorSpec.size.resources.requests, "cpu", "200m")
          memory = lookup(local.prometheusOperatorSpec.size.resources.requests, "memory", "512Mi")
        }
        limits = {
          cpu    = lookup(local.prometheusOperatorSpec.size.resources.limits, "cpu", "200m")
          memory = lookup(local.prometheusOperatorSpec.size.resources.limits, "memory", "512Mi")
        }
      }
      # priorityClassName = "facets-critical"
      nodeSelector = local.nodeSelector
      tolerations  = local.tolerations
    }
    prometheus = {
      enabled = lookup(local.prometheusSpec, "enabled", true)
      prometheusSpec = {
        enableRemoteWriteReceiver               = true
        ruleSelectorNilUsesHelmValues           = false
        serviceMonitorSelectorNilUsesHelmValues = false
        retention                               = local.prometheus_retention
        resources = {
          requests = {
            cpu    = lookup(local.prometheusSpec.size.resources.requests, "cpu", "1000m")
            memory = lookup(local.prometheusSpec.size.resources.requests, "memory", "4Gi")
          }
          limits = {
            cpu    = lookup(local.prometheusSpec.size.resources.limits, "cpu", "1000m")
            memory = lookup(local.prometheusSpec.size.resources.limits, "memory", "4Gi")
          }
        }
        nodeSelector = local.nodeSelector
        tolerations  = local.tolerations
        additionalScrapeConfigs = [
          {
            job_name = "kubernetes-pods"
            kubernetes_sd_configs = [
              {
                role = "pod"
              }
            ]
            relabel_configs = [
              {
                action        = "keep"
                regex         = "true"
                source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
              },
              {
                action        = "replace"
                regex         = "(.+)"
                source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
                target_label  = "__metrics_path__"
              },
              {
                action        = "replace"
                regex         = "([^:]+)(?::\\d+)?;(\\d+)"
                replacement   = "$1:$2"
                source_labels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
                target_label  = "__address__"
              },
              {
                action = "labelmap"
                regex  = "__meta_kubernetes_pod_label_(.+)"
              },
              {
                action        = "replace"
                source_labels = ["__meta_kubernetes_namespace"]
                target_label  = "kubernetes_namespace"
              },
              {
                action        = "replace"
                source_labels = ["__meta_kubernetes_pod_name"]
                target_label  = "kubernetes_pod_name"
              }
            ]
          }
        ]
        walCompression = true
        # priorityClassName = "facets-critical"
      }
    }
    alertmanager = {
      enabled = lookup(local.alertmanagerSpec, "enabled", true)
      annotations = {
        "cluster-autoscaler.kubernetes.io/safe-to-evict" = "true"
      }
      alertmanagerSpec = {
        resources = {
          requests = {
            cpu    = lookup(local.alertmanagerSpec.size.resources.requests, "cpu", "1000m")
            memory = lookup(local.alertmanagerSpec.size.resources.requests, "memory", "2Gi")
          }
          limits = {
            cpu    = lookup(local.alertmanagerSpec.size.resources.limits, "cpu", lookup(local.alertmanagerSpec.size.resources.requests, "cpu", "1000m"))
            memory = lookup(local.alertmanagerSpec.size.resources.limits, "memory", lookup(local.alertmanagerSpec.size.resources.requests, "memory", "2Gi"))
          }
        }
        nodeSelector = local.nodeSelector
        tolerations  = local.tolerations
        # priorityClassName = "facets-critical"
      }
    }
    grafana = {
      enabled       = lookup(local.grafanaSpec, "enabled", true)
      adminUser     = "admin"
      adminPassword = "prom-operator"
      sidecar = {
        datasources = {
          defaultDatasourceEnabled = false
        }
      }
      podAnnotations = {
        "cluster-autoscaler.kubernetes.io/safe-to-evict" = "true"
      }
      resources = {
        requests = {
          cpu    = lookup(local.grafanaSpec.size.resources.requests, "cpu", "200m")
          memory = lookup(local.grafanaSpec.size.resources.requests, "memory", "512Mi")
        }
        limits = {
          cpu    = lookup(local.grafanaSpec.size.resources.limits, "cpu", "200m")
          memory = lookup(local.grafanaSpec.size.resources.limits, "memory", "512Mi")
        }
      }
      nodeSelector             = local.nodeSelector
      tolerations              = local.tolerations
      defaultDashboardsEnabled = false
      "grafana.ini" = {
        security = {
          allow_embedding = true
          cookie_secure   = true
          cookie_samesite = "none"
        }
        server = {
          domain              = local.cc_host
          root_url            = "%(protocol)s://%(domain)s:%(http_port)s/tunnel/${var.environment.cluster_id}/grafana/"
          serve_from_sub_path = true
        }
        live = {
          allowed_origins = "https://${local.cc_host}"
        }
        "auth.anonymous" = {
          enabled  = true
          org_name = "Main Org."
          org_role = "Editor"
        }
      }
      imageRenderer = {
        enabled = true
        image = {
          repository = "hferreira/grafana-image-renderer"
        }
        podAnnotations = {
          "cluster-autoscaler.kubernetes.io/safe-to-evict" = "true"
        }
        # priorityClassName = "facets-critical"
        nodeSelector = local.nodeSelector
        tolerations  = local.tolerations
      }
      additionalDataSources = concat([
        {
          name      = "Prometheus"
          type      = "prometheus"
          uid       = "prometheus"
          url       = "http://${module.name.name}-prometheus.${local.namespace}.svc.cluster.local:9090"
          access    = "proxy"
          isDefault = true
          jsonData = {
            timeInterval = "30s"
            timeout      = 600
          }
        }
      ], lookup(local.grafanaSpec, "additionalDataSources", []))
      # priorityClassName = "facets-critical"
    }
    "kube-state-metrics" = {
      enabled = lookup(local.kubeStateMetricsSpec, "enabled", true)
      collectors = distinct(concat([
        "certificatesigningrequests", "configmaps", "cronjobs", "daemonsets", "deployments",
        "endpoints", "horizontalpodautoscalers", "verticalpodautoscalers", "ingresses", "jobs",
        "leases", "limitranges", "mutatingwebhookconfigurations", "namespaces", "networkpolicies",
        "nodes", "persistentvolumeclaims", "persistentvolumes", "poddisruptionbudgets", "pods",
        "replicasets", "replicationcontrollers", "resourcequotas", "secrets", "services",
        "statefulsets", "storageclasses", "validatingwebhookconfigurations", "volumeattachments"
      ], lookup(local.kubeStateMetricsSpec, "collectors", [])))
      extraArgs = [
        "--metric-labels-allowlist=pods=[*],nodes=[*],ingresses=[*]",
        "--resources=certificatesigningrequests,configmaps,cronjobs,daemonsets,deployments,endpoints,horizontalpodautoscalers,ingresses,jobs,leases,limitranges,mutatingwebhookconfigurations,namespaces,networkpolicies,nodes,persistentvolumeclaims,persistentvolumes,poddisruptionbudgets,pods,replicasets,replicationcontrollers,resourcequotas,secrets,services,statefulsets,storageclasses,validatingwebhookconfigurations,volumeattachments"
      ]
      # priorityClassName = "facets-critical"
      nodeSelector = local.nodeSelector
      tolerations  = local.tolerations
    }
    "prometheus-node-exporter" = {
      nodeSelector = {
        "kubernetes.io/os" = "linux"
      }
      # priorityClassName = "facets-critical"
    }
  }
}
