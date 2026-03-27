locals {
  # ── Promtail sizing ───────────────────────────────────────────────────────────
  promtail_resources = lookup(local.promtail_size, "resources", {})
  promtail_requests  = lookup(local.promtail_resources, "requests", {})
  promtail_limits    = lookup(local.promtail_resources, "limits", {})

  # ── CRI vs Docker pipeline stages ─────────────────────────────────────────────
  cri_pipeline_stages = [
    {
      cri = {}
    }
  ]

  docker_pipeline_stages = [
    {
      docker = {}
    }
  ]

  pipeline_stages = local.container_runtime == "docker" ? local.docker_pipeline_stages : local.cri_pipeline_stages

  # ── Constructed default Promtail values ───────────────────────────────────────
  constructed_promtail_values = {
    fullnameOverride = "${var.instance_name}-promtail"

    config = {
      logLevel   = "info"
      serverPort = 3101

      clients = [
        {
          url = "http://${var.instance_name}-loki-gateway.${local.namespace}.svc.cluster.local/loki/api/v1/push"
        }
      ]

      snippets = {
        # pipelineStages applied globally to all scrape jobs
        pipelineStages = local.pipeline_stages

        # extraScrapeConfigs is a raw YAML string inserted into Promtail config.
        # DO NOT embed jsonencode() or Terraform interpolations that produce JSON here —
        # JSON is not valid YAML block syntax and will break Promtail config parsing.
        # Pipeline stages are already applied globally above; do not repeat them here.
        extraScrapeConfigs = <<-EOT
- job_name: kubernetes-pods-app
  kubernetes_sd_configs:
    - role: pod
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_node_name]
      target_label: __host__
    - action: labelmap
      regex: __meta_kubernetes_pod_label_(.+)
    - action: replace
      replacement: $1
      separator: /
      source_labels:
        - __meta_kubernetes_namespace
        - __meta_kubernetes_pod_name
      target_label: job
    - action: replace
      source_labels: [__meta_kubernetes_namespace]
      target_label: namespace
    - action: replace
      source_labels: [__meta_kubernetes_pod_name]
      target_label: pod
    - action: replace
      source_labels: [__meta_kubernetes_pod_container_name]
      target_label: container
    - replacement: /var/log/pods/*$1/*.log
      separator: /
      source_labels:
        - __meta_kubernetes_pod_uid
        - __meta_kubernetes_pod_container_name
      target_label: __path__
EOT
      }
    }

    # DaemonSet must tolerate control-plane nodes to collect logs cluster-wide
    tolerations = concat(
      local.tolerations,
      [
        {
          key      = "node-role.kubernetes.io/master"
          operator = "Exists"
          effect   = "NoSchedule"
        },
        {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ]
    )

    nodeSelector = local.node_selector

    # DaemonSet processes logs for every pod on every node — size appropriately.
    # These defaults handle ~100 pods/node; increase for higher log volumes.
    resources = {
      requests = {
        cpu    = lookup(local.promtail_requests, "cpu", "200m")
        memory = lookup(local.promtail_requests, "memory", "256Mi")
      }
      limits = {
        cpu    = lookup(local.promtail_limits, "cpu", "500m")
        memory = lookup(local.promtail_limits, "memory", "512Mi")
      }
    }

    serviceMonitor = {
      enabled = local.prometheus_enabled
    }

    defaultVolumes = [
      {
        name = "run"
        hostPath = {
          path = "/run/promtail"
        }
      },
      {
        name = "containers"
        hostPath = {
          path = "/var/lib/docker/containers"
        }
      },
      {
        name = "pods"
        hostPath = {
          path = "/var/log/pods"
        }
      }
    ]

    defaultVolumeMounts = [
      {
        mountPath = "/run/promtail"
        name      = "run"
      },
      {
        mountPath = "/var/lib/docker/containers"
        name      = "containers"
        readOnly  = true
      },
      {
        mountPath = "/var/log/pods"
        name      = "pods"
        readOnly  = true
      }
    ]
  }
}
