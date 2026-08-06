module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 48
  resource_name   = var.instance_name
  resource_type   = "loki_s3"
  globally_unique = true
}

# -----------------------------------------------------------------------------
# IRSA: IAM Role for Loki Service Account to access S3
# -----------------------------------------------------------------------------

resource "aws_iam_role" "loki" {
  name = "${module.name.name}-loki"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider}:aud" = "sts.amazonaws.com"
            "${local.oidc_provider}:sub" = "system:serviceaccount:${local.namespace}:${local.sa_name}"
          }
        }
      }
    ]
  })

  tags = local.instance_tags
}

resource "aws_iam_policy" "loki_s3" {
  name        = "${module.name.name}-loki-s3"
  description = "S3 read-write access for Loki log storage"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
        ]
        Resource = [
          local.bucket_arn,
          "${local.bucket_arn}/*"
        ]
      }
    ]
  })

  tags = local.instance_tags
}

resource "aws_iam_role_policy_attachment" "loki_s3" {
  role       = aws_iam_role.loki.name
  policy_arn = aws_iam_policy.loki_s3.arn
}

# -----------------------------------------------------------------------------
# Kubernetes Namespace
# -----------------------------------------------------------------------------

resource "kubernetes_namespace_v1" "loki" {
  count = local.namespace != "default" && local.namespace != "kube-system" ? 1 : 0

  metadata {
    name = local.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "facets"
      "facets.cloud/instance"        = var.instance_name
    }
  }
}

# -----------------------------------------------------------------------------
# Loki Distributed Helm Release
# -----------------------------------------------------------------------------

resource "helm_release" "loki" {
  name             = "${var.instance_name}-loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-distributed"
  version          = lookup(var.instance.spec, "loki_chart_version", "0.80.0")
  namespace        = local.namespace
  create_namespace = false
  cleanup_on_fail  = true
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      loki = {
        structuredConfig = {
          auth_enabled = false

          server = {
            http_listen_port = 3100
          }

          ingester = {
            chunk_idle_period   = "1h"
            max_chunk_age       = "1h"
            chunk_target_size   = 1048576
            chunk_retain_period = "30s"

            lifecycler = {
              ring = {
                replication_factor = 1
              }
            }
          }

          schema_config = {
            configs = [
              {
                from         = "2024-01-01"
                store        = "boltdb-shipper"
                object_store = "s3"
                schema       = "v11"
                index = {
                  prefix = "loki_index_"
                  period = "24h"
                }
              }
            ]
          }

          storage_config = {
            aws = {
              s3               = "s3://${local.aws_region}/${local.bucket_name}"
              s3forcepathstyle = false
            }
            boltdb_shipper = {
              shared_store = "s3"
              cache_ttl    = "48h"
            }
          }

          compactor = {
            shared_store           = "s3"
            working_directory      = "/var/loki/compactor"
            compaction_interval    = "5m"
            retention_enabled      = true
            retention_delete_delay = "2h"
          }

          limits_config = {
            retention_period           = local.retention_period
            enforce_metric_name        = false
            reject_old_samples         = true
            reject_old_samples_max_age = "168h"
            max_query_length           = local.retention_period
            volume_enabled             = true
          }

          query_range = {
            align_queries_with_step = true
          }

          frontend = {
            max_outstanding_per_tenant = 2048
            compress_responses         = true
          }
        }
      }

      serviceAccount = {
        create = true
        name   = local.sa_name
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.loki.arn
        }
      }

      distributor = {
        replicas = lookup(local.distributor, "replicas", 1)
        resources = {
          requests = {
            cpu    = lookup(local.distributor_requests, "cpu", "250m")
            memory = lookup(local.distributor_requests, "memory", "256Mi")
          }
          limits = {
            cpu    = lookup(local.distributor_limits, "cpu", "500m")
            memory = lookup(local.distributor_limits, "memory", "512Mi")
          }
        }
      }

      ingester = {
        replicas = lookup(local.ingester, "replicas", 1)
        resources = {
          requests = {
            cpu    = lookup(local.ingester_requests, "cpu", "250m")
            memory = lookup(local.ingester_requests, "memory", "512Mi")
          }
          limits = {
            cpu    = lookup(local.ingester_limits, "cpu", "500m")
            memory = lookup(local.ingester_limits, "memory", "1Gi")
          }
        }
        persistence = {
          enabled = true
          size    = "10Gi"
        }
      }

      querier = {
        replicas = lookup(local.querier, "replicas", 1)
        resources = {
          requests = {
            cpu    = lookup(local.querier_requests, "cpu", "250m")
            memory = lookup(local.querier_requests, "memory", "256Mi")
          }
          limits = {
            cpu    = lookup(local.querier_limits, "cpu", "500m")
            memory = lookup(local.querier_limits, "memory", "512Mi")
          }
        }
      }

      queryFrontend = {
        replicas = lookup(local.query_frontend, "replicas", 1)
        resources = {
          requests = {
            cpu    = lookup(local.query_frontend_requests, "cpu", "125m")
            memory = lookup(local.query_frontend_requests, "memory", "128Mi")
          }
          limits = {
            cpu    = lookup(local.query_frontend_limits, "cpu", "250m")
            memory = lookup(local.query_frontend_limits, "memory", "256Mi")
          }
        }
      }

      compactor = {
        enabled = true
        resources = {
          requests = {
            cpu    = lookup(local.compactor_requests, "cpu", "100m")
            memory = lookup(local.compactor_requests, "memory", "256Mi")
          }
          limits = {
            cpu    = lookup(local.compactor_limits, "cpu", "250m")
            memory = lookup(local.compactor_limits, "memory", "512Mi")
          }
        }
        persistence = {
          enabled = true
          size    = "10Gi"
        }
      }

      gateway = {
        enabled  = true
        replicas = 1
      }
    })
    , yamlencode(local.loki_custom_values)
  ]

  depends_on = [
    kubernetes_namespace_v1.loki,
    aws_iam_role_policy_attachment.loki_s3
  ]
}

# -----------------------------------------------------------------------------
# Promtail Helm Release
# -----------------------------------------------------------------------------

resource "helm_release" "promtail" {
  name             = "${var.instance_name}-promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  version          = lookup(var.instance.spec, "promtail_chart_version", "6.16.6")
  namespace        = local.namespace
  create_namespace = false
  cleanup_on_fail  = true
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      config = {
        clients = [
          {
            url = "http://${var.instance_name}-loki-loki-distributed-gateway.${local.namespace}.svc.cluster.local/loki/api/v1/push"
          }
        ]

        snippets = {
          scrapeConfigs = <<-SCRAPECONFIG
            - job_name: kubernetes-pods
              pipeline_stages:
                - cri: {}
              kubernetes_sd_configs:
                - role: pod
              relabel_configs:
                - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
                  action: drop
                  regex: 'false'
                - source_labels: [__meta_kubernetes_pod_label_name]
                  target_label: __service__
                - source_labels: [__meta_kubernetes_pod_node_name]
                  target_label: __host__
                - action: labelmap
                  regex: __meta_kubernetes_pod_label_(.+)
                - action: replace
                  replacement: $1
                  separator: /
                  source_labels:
                    - __meta_kubernetes_namespace
                    - __service__
                  target_label: job
                - action: replace
                  source_labels:
                    - __meta_kubernetes_namespace
                  target_label: namespace
                - action: replace
                  source_labels:
                    - __meta_kubernetes_pod_name
                  target_label: pod
                - action: replace
                  source_labels:
                    - __meta_kubernetes_pod_container_name
                  target_label: container
                - replacement: /var/log/pods/*$1/*.log
                  separator: /
                  source_labels:
                    - __meta_kubernetes_pod_uid
                    - __meta_kubernetes_pod_container_name
                  target_label: __path__
          SCRAPECONFIG
        }
      }

      resources = {
        requests = {
          cpu    = lookup(local.promtail_requests, "cpu", "100m")
          memory = lookup(local.promtail_requests, "memory", "128Mi")
        }
        limits = {
          cpu    = lookup(local.promtail_limits, "cpu", "200m")
          memory = lookup(local.promtail_limits, "memory", "256Mi")
        }
      }
    })
    , yamlencode(local.promtail_custom_values)
  ]

  depends_on = [
    helm_release.loki
  ]
}

# -----------------------------------------------------------------------------
# Grafana Datasource ConfigMap (auto-discovered by Grafana sidecar)
# -----------------------------------------------------------------------------

resource "kubernetes_config_map_v1" "grafana_datasource" {
  metadata {
    name      = "${var.instance_name}-loki-datasource"
    namespace = "default"
    labels = {
      grafana_datasource = "1"
    }
  }

  data = {
    "loki-datasource.yaml" = yamlencode({
      apiVersion = 1
      datasources = [
        {
          name   = "Loki"
          type   = "loki"
          access = "proxy"
          url    = "http://${var.instance_name}-loki-loki-distributed-gateway.${local.namespace}.svc.cluster.local"
          jsonData = {
            maxLines = 1000
          }
        }
      ]
    })
  }

  depends_on = [
    helm_release.loki
  ]
}
