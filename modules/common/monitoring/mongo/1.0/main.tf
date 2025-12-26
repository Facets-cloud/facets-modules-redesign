# MongoDB Monitoring Module - Complete Monitoring Stack
# Deploys: MongoDB Exporter, ServiceMonitor, PrometheusRules


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

      extraArgs = [
        "--collect-all",
        "--mongodb.direct-connect=false"
      ]

      image = {
        repository = "percona/mongodb_exporter"
        tag        = "0.40.0"
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
        annotations = {
          "app.kubernetes.io/name"      = "mongodb-monitoring"
          "app.kubernetes.io/instance"  = var.instance_name
          "app.kubernetes.io/component" = "exporter"
        }
      }

      podAnnotations = {
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
      labels = merge(
        local.common_labels,
        {
          release = var.inputs.prometheus.attributes.prometheus_release
        }
      )
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
