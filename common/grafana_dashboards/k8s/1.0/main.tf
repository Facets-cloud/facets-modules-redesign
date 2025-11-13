locals {
  spec = lookup(var.instance, "spec", {})

  # Get dashboard configurations
  dashboards = lookup(local.spec, "dashboards", {})

  # Get Grafana namespace from prometheus input (grafana is deployed in same namespace as prometheus)
  grafana_namespace = lookup(var.inputs.prometheus.attributes, "namespace", var.environment.namespace)

  # Extract dashboard names and ConfigMap names for outputs
  dashboard_names = [for key, dashboard in local.dashboards : lookup(dashboard, "name", key)]
  configmap_names = [for key, dashboard in local.dashboards : "${var.instance_name}-${key}"]
}

# Create ConfigMap for each dashboard with Grafana auto-discovery labels
resource "kubernetes_config_map" "grafana_dashboard" {
  for_each = local.dashboards

  metadata {
    name      = "${var.instance_name}-${each.key}"
    namespace = local.grafana_namespace

    labels = merge(
      {
        # Required labels for Grafana dashboard auto-discovery
        # These labels trigger the Grafana sidecar to import this dashboard
        "grafana_dashboard"          = "1"
        "grafana_dashboard_instance" = "grafana_dashboard"

        # Standard Kubernetes labels
        "app.kubernetes.io/name"       = var.instance_name
        "app.kubernetes.io/instance"   = var.instance_name
        "app.kubernetes.io/component"  = "dashboard"
        "app.kubernetes.io/managed-by" = "facets"
        "dashboard-name"               = replace(lower(replace(lookup(each.value, "name", each.key), " ", "-")), "/[^a-z0-9-_.]/", "")
      },
      var.environment.cloud_tags
    )

    annotations = merge(
      {
        # Grafana folder organization - always enabled
        "grafana_folder" = lookup(each.value, "folder", "General")

        # Facets metadata
        "facets.cloud/instance"    = var.instance_name
        "facets.cloud/environment" = var.environment.name
      }
    )
  }

  data = {
    "${replace(lower(replace(lookup(each.value, "name", each.key), " ", "-")), "/[^a-z0-9-_.]/", "")}.json" = lookup(each.value, "json", "{}")
  }
}
