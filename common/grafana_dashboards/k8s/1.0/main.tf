locals {
  spec = lookup(var.instance, "spec", {})

  # Get dashboard configurations
  dashboards = lookup(local.spec, "dashboards", {})

  # Standard kube-prometheus-stack label for Grafana sidecar auto-discovery
  # This is the convention used by kube-prometheus-stack Helm chart
  instance_selector = "grafana_dashboard"

  # Get Grafana namespace from prometheus input (grafana is deployed in same namespace as prometheus)
  grafana_namespace = lookup(var.inputs.prometheus.attributes, "namespace", var.environment.namespace)

  # Separate dashboards by source type
  grafana_id_dashboards = {
    for key, dashboard in local.dashboards :
    key => dashboard
    if lookup(dashboard, "source_type", "json") == "grafana_id"
  }

  json_dashboards = {
    for key, dashboard in local.dashboards :
    key => dashboard
    if lookup(dashboard, "source_type", "json") == "json"
  }
}

# Fetch dashboards from grafana.com for dashboards with source_type="grafana_id"
data "http" "grafana_dashboard" {
  for_each = local.grafana_id_dashboards

  url = "https://grafana.com/api/dashboards/${lookup(each.value, "dashboard_id", "")}"

  request_headers = {
    Accept = "application/json"
  }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Failed to fetch dashboard ${each.key} (ID: ${lookup(each.value, "dashboard_id", "")}). HTTP status: ${self.status_code}"
    }
  }
}

locals {
  # Parse fetched dashboards and extract the dashboard JSON
  # Grafana.com API returns: {"json": {...dashboard json...}}
  fetched_dashboard_content = {
    for key, response in data.http.grafana_dashboard :
    key => jsondecode(response.response_body).json
  }

  # Prepare all dashboards with their JSON content
  # For fetched dashboards: use the downloaded JSON
  # For manual dashboards: use the provided JSON
  all_dashboards = merge(
    # Fetched dashboards (from grafana.com)
    {
      for key, dashboard in local.grafana_id_dashboards :
      key => merge(
        dashboard,
        {
          dashboard_json = jsonencode(local.fetched_dashboard_content[key])
        }
      )
    },
    # Manual JSON dashboards
    {
      for key, dashboard in local.json_dashboards :
      key => merge(
        dashboard,
        {
          dashboard_json = lookup(dashboard, "json", "{}")
        }
      )
    }
  )

  # Extract dashboard names and ConfigMap names for outputs
  dashboard_names = [for key, dashboard in local.all_dashboards : lookup(dashboard, "name", key)]
  configmap_names = [for key, dashboard in local.all_dashboards : "${var.instance_name}-${key}"]
}

# Create ConfigMap for each dashboard with Grafana auto-discovery labels
resource "kubernetes_config_map" "grafana_dashboard" {
  for_each = local.all_dashboards

  metadata {
    name      = "${var.instance_name}-${each.key}"
    namespace = local.grafana_namespace

    labels = merge(
      {
        # Required labels for Grafana dashboard auto-discovery
        "${local.instance_selector}" = "1"

        # Standard Kubernetes labels
        "app.kubernetes.io/name"       = var.instance_name
        "app.kubernetes.io/instance"   = var.instance_name
        "app.kubernetes.io/component"  = "dashboard"
        "app.kubernetes.io/managed-by" = "facets"
        "dashboard-name"               = replace(lower(replace(lookup(each.value, "name", each.key), " ", "-")), "/[^a-z0-9-_.]/", "")
      },
      var.environment.cloud_tags,
      lookup(each.value, "labels", {})
    )

    annotations = merge(
      {
        # Grafana folder organization - always enabled
        "grafana_folder" = lookup(each.value, "folder", "General")

        # Facets metadata
        "facets.cloud/instance"    = var.instance_name
        "facets.cloud/environment" = var.environment.name
        "facets.cloud/source-type" = lookup(each.value, "source_type", "json")
      },
      # Add dashboard ID annotation for grafana_id source type
      lookup(each.value, "source_type", "json") == "grafana_id" ? {
        "facets.cloud/grafana-dashboard-id" = lookup(each.value, "dashboard_id", "")
      } : {}
    )
  }

  data = {
    "${replace(lower(replace(lookup(each.value, "name", each.key), " ", "-")), "/[^a-z0-9-_.]/", "")}.json" = lookup(each.value, "dashboard_json", "{}")
  }
}
