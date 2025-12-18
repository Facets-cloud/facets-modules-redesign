# MongoDB Monitoring Module - Complete Monitoring Stack
# Deploys: MongoDB Exporter, ServiceMonitor, PrometheusRules, and Grafana Dashboard


# ========================================
# MongoDB Exporter Deployment via Helm
# ========================================
resource "helm_release" "mongodb_exporter" {
  count = local.enable_metrics ? 1 : 0

  name       = "${local.name}-exporter"
  namespace  = local.mongo_namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-mongodb-exporter"
  version    = "3.15.0"

  values = [
    yamlencode({
      mongodb = {
        uri = local.mongodb_uri
      }

      image = {
        repository = "percona/mongodb_exporter"
        tag        = "0.47"
      }

      serviceAccount = {
        create = false
      }

      serviceMonitor = {
        enabled  = true
        interval = local.metrics_interval

        additionalLabels = {
          # THIS is required because your Prometheus has:
          # serviceMonitorSelector.matchLabels.release
          release = var.inputs.prometheus.attributes.prometheus_release
        }
      }

      service = {
        labels = {
          "app.kubernetes.io/name"      = "mongodb-monitoring"
          "app.kubernetes.io/instance"  = var.instance_name
          "app.kubernetes.io/component" = "exporter"
        }
      }

      podLabels = {
        "app.kubernetes.io/name"      = "mongodb-monitoring"
        "app.kubernetes.io/instance"  = var.instance_name
        "app.kubernetes.io/component" = "exporter"
      }

      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
      }
    })
  ]
}


# ========================================
# PrometheusRule for Alerts
# ========================================

module "prometheus_rule" {
  count  = local.enable_alerts ? 1 : 0
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name         = local.name
  namespace    = local.prometheus_namespace
  release_name = "mongo-alerts-${substr(var.environment.unique_name, 0, 8)}"

  data = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "${local.name}-alerts"
      namespace = local.prometheus_namespace
      labels    = local.common_labels
    }

    spec = {
      groups = [
        {
          name     = "${var.instance_name}-mongodb-alerts"
          interval = "30s"
          rules    = local.alert_rules
        }
      ]
    }
  }

  advanced_config = {
    wait            = false
    timeout         = 300
    cleanup_on_fail = true
    max_history     = 3
  }
}

# ========================================
# Grafana Dashboard
# ========================================

# module "grafana_dashboard" {
#   count  = local.enable_dashboard ? 1 : 0
#   source = "../../../grafana_dashboards/k8s/1.0"

#   instance_name = "${var.instance_name}-dashboard"
#   environment   = var.environment

#   instance = {
#     kind    = "grafana_dashboards"
#     flavor  = "k8s"
#     version = "1.0"
#     spec = {
#       dashboards = {
#         mongodb = {
#           name   = "MongoDB Metrics - ${var.instance_name}"
#           folder = lookup(var.instance.spec, "dashboard_folder", "MongoDB")
#           json   = file("${path.module}/dashboard.json")
#         }
#       }
#     }
#   }
#   inputs = {}
# }
