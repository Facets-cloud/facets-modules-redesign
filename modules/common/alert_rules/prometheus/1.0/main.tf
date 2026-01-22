# Generic Alert Rules Module - PrometheusRule Deployment
# Deploys user-defined alert rules to Prometheus Operator

module "prometheus_rule" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"

  name         = local.name
  namespace    = local.namespace
  release_name = "alert-rules-${substr(var.environment.unique_name, 0, 8)}"

  data = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "${local.name}-rules"
      namespace = local.namespace
      labels    = local.common_labels
    }

    spec = {
      groups = local.alert_groups
    }
  }

  advanced_config = {
    wait            = false
    timeout         = 300
    cleanup_on_fail = true
    max_history     = 10
  }
}
