locals {
  output_interfaces = {}
  output_attributes = {
    namespace            = local.namespace
    prometheus_url       = "http://${local.helm_name}.${var.environment.namespace}.svc.cluster.local:9090"
    alertmanager_url     = "http://${local.helm_name}-alertmanager.${var.environment.namespace}.svc.cluster.local:9093"
    grafana_url          = "http://${local.helm_name}-grafana.${var.environment.namespace}.svc.cluster.local:80"
    helm_release_id      = helm_release.prometheus-operator.id
    prometheus_release   = local.helm_name
    prometheus_service   = "${local.helm_name}-prometheus"
    alertmanager_service = "${local.helm_name}-alertmanager"
    grafana_service      = "${local.helm_name}-grafana"
  }
}