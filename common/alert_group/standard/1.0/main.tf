locals {
  spec = lookup(var.instance, "spec", {})

  # Get alert rules from spec
  rules = lookup(local.spec, "rules", {})

  # Get Prometheus release ID from prometheus input
  prometheus_release = lookup(var.inputs.prometheus.attributes, "helm_release_id", "prometheus")

  # Transform rules into PrometheusRule format, filtering out disabled rules
  alert_rules = [
    for rule_name, rule_object in local.rules :
    {
      alert = rule_name
      expr  = rule_object.expr
      for   = rule_object.for
      labels = merge(
        lookup(rule_object, "labels", {}),
        {
          resource_type = rule_object.resource_type
          resource_name = rule_object.resource_name
          resourceType  = rule_object.resource_type
          resourceName  = rule_object.resource_name
          alert_type    = lookup(rule_object, "alert_type", null)
          severity      = lookup(rule_object, "severity", null)
        }
      )
      annotations = merge(
        lookup(rule_object, "annotations", {}),
        {
          message = rule_object.message
          summary = rule_object.summary
        }
      )
    } if !lookup(rule_object, "disabled", false)
  ]

  # Extract rule names for outputs
  rule_names = [for key, rule in local.rules : key if !lookup(rule, "disabled", false)]

  # Metadata for PrometheusRule
  prometheus_rule_metadata = {
    name      = "${var.instance_name}-alert-group"
    namespace = var.environment.namespace
    labels = merge(
      {
        alert_group_name               = var.instance_name
        role                           = "alert-rules"
        release                        = local.prometheus_release
        "app.kubernetes.io/name"       = var.instance_name
        "app.kubernetes.io/instance"   = var.instance_name
        "app.kubernetes.io/component"  = "alert-rules"
        "app.kubernetes.io/managed-by" = "facets"
      },
      var.environment.cloud_tags
    )
    annotations = merge(
      {
        owner                      = "facets"
        "facets.cloud/instance"    = var.instance_name
        "facets.cloud/environment" = var.environment.name
      }
    )
  }

  # PrometheusRule manifest
  prometheus_rule_manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata   = local.prometheus_rule_metadata
    spec = {
      groups = [
        {
          name  = "${var.instance_name}-alert-rules"
          rules = local.alert_rules
        }
      ]
    }
  }
}

# Deploy PrometheusRule using helm_release with any-k8s-resource chart
resource "helm_release" "alert_group" {
  name             = "${var.instance_name}-alert-group"
  chart            = "https://github.com/Facets-cloud/facets-utility-modules/raw/master/any-k8s-resource/dynamic-k8s-resource-0.1.0.tgz"
  namespace        = var.environment.namespace
  create_namespace = true
  version          = "0.1.0"
  timeout          = 300
  cleanup_on_fail  = true
  wait             = false
  max_history      = 10

  values = [
    yamlencode({
      resource = local.prometheus_rule_manifest
    })
  ]
}
