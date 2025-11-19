locals {
  output_interfaces = {}
  output_attributes = {
    prometheus_url          = "http://${module.name.name}.${var.environment.namespace}.svc.cluster.local:9090"
    alertmanager_url        = "http://${module.name.name}-alertmanager.${var.environment.namespace}.svc.cluster.local:9093"
    grafana_url             = "http://${module.name.name}-grafana.${var.environment.namespace}.svc.cluster.local:80"
    helm_release_id         = helm_release.prometheus-operator.id
    prometheus_release_name = module.name.name
    namespace               = local.namespace
    prometheus_service      = "${module.name.name}-prometheus"
    alertmanager_service    = "${module.name.name}-alertmanager"
    grafana_service         = "${module.name.name}-grafana"
  }
}