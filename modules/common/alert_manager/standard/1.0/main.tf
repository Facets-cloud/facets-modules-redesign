# Alertmanager Receiver Module - AlertmanagerConfig Deployment
# Configures notification receivers and routing rules for Prometheus Alertmanager

module "alertmanager_config" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name         = local.name
  namespace    = local.namespace
  release_name = "alertmanager-config-${substr(var.environment.unique_name, 0, 8)}"

  data = {
    apiVersion = "monitoring.coreos.com/v1alpha1"
    kind       = "AlertmanagerConfig"

    metadata = {
      name      = "${local.name}-config"
      namespace = local.namespace
      labels = {
        "app.kubernetes.io/name"       = "alert_manager"
        "app.kubernetes.io/instance"   = var.instance_name
        "app.kubernetes.io/managed-by" = "facets"
        "facets.cloud/environment"     = var.environment.name
      }
    }

    spec = {
      # Receivers define notification channels
      receivers = local.receivers

      # Route defines how alerts are routed to receivers
      route = local.default_route != null ? {
        receiver       = local.default_route.receiver
        groupBy        = local.default_route.groupBy
        groupWait      = local.default_route.groupWait
        groupInterval  = local.default_route.groupInterval
        repeatInterval = local.default_route.repeatInterval
        # Nested routes for additional routing rules
        routes = length(local.routes) > 1 ? slice(local.routes, 1, length(local.routes)) : []
      } : null
    }
  }

  advanced_config = {
    wait            = false
    timeout         = 300
    cleanup_on_fail = true
    max_history     = 10
  }
}
