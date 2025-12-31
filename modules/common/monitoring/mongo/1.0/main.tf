# MongoDB Monitoring Module - Complete Monitoring Stack
# Deploys: MongoDB Exporter (v0.47.2), ServiceMonitor, PrometheusRules
#
# Versions:
# - Helm Chart: prometheus-mongodb-exporter v3.15.0
# - App Version: percona/mongodb_exporter v0.47.2
# - Compatible with MongoDB 4.0+, including replica sets


# ========================================
# MongoDB Exporter Deployment via Helm
# ========================================
resource "helm_release" "mongodb_exporter" {
  count = local.enable_metrics ? 1 : 0

  name       = "${local.name}-exporter"
  namespace  = local.mongo_namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-mongodb-exporter"
  version    = "3.15.0" # Helm chart version (supports custom image tags)

  values = [
    yamlencode(
      merge(
        {
          mongodb = {
            uri = local.mongodb_uri
          }

          # Exporter configuration for v0.47.2
          extraArgs = [
            "--collect-all",                  # Enable all collectors
            "--mongodb.direct-connect=false", # Required for replica sets (default is true in v0.47.2)
            "--log.level=info"                # Enable info logging for troubleshooting
          ]

          # ServiceMonitor configuration for Prometheus Operator
          serviceMonitor = {
            enabled  = true
            interval = local.metrics_interval

            additionalLabels = {
              # Required: Prometheus Operator uses serviceMonitorSelector.matchLabels.release
              # to discover ServiceMonitor resources
              release = var.inputs.prometheus.attributes.prometheus_release
            }

            # Metric relabeling: Add Facets resource labels to all metrics
            metricRelabelings = [
              {
                targetLabel = "facets_resource_type"
                replacement = "mongo"
              },
              {
                targetLabel = "facets_resource_name"
                replacement = var.instance_name
              }
            ]
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

          resources = local.resources
        },
        length(local.tolerations) > 0 ? {
          tolerations = local.tolerations
        } : {},

        length(local.node_selector) > 0 ? {
          nodeSelector = local.node_selector
        } : {},

        # Merge additional helm values provided by user
        lookup(var.instance.spec, "additional_helm_values", {})
      )
    )
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
