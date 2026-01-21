# ========================================
# Grafana Dashboard ConfigMap
# ========================================
# Deploys PostgreSQL dashboard to Grafana via ConfigMap
# The dashboard JSON is read from file and placeholders are replaced

resource "kubernetes_config_map_v1" "grafana_dashboard" {
  metadata {
    name      = "${local.name}-grafana-dashboard"
    namespace = local.prometheus_namespace

    labels = merge(
      local.common_labels,
      {
        grafana_dashboard          = "1"                 # Label used by Grafana sidecar to discover dashboards
        grafana_dashboard_instance = "grafana_dashboard" # Instance label for Grafana dashboard selector
      }
    )
  }

  data = {
    "postgresql-dashboard.json" = jsonencode(local.grafana_dashboard_json)
  }
}
