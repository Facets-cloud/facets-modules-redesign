locals {
  spec = lookup(var.instance, "spec", {})

  # Get alert rules from spec
  rules = lookup(local.spec, "rules", {})

  # Get Prometheus namespace and release name from prometheus input
  prometheus_namespace = lookup(var.inputs.prometheus.attributes, "namespace", var.environment.namespace)
  prometheus_release   = lookup(var.inputs.prometheus.attributes, "helm_release_name", "prometheus")

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
}

# Create PrometheusRule CRD for alert rules
resource "kubernetes_manifest" "prometheus_rule" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"

    metadata = {
      name      = "${var.instance_name}-alert-group"
      namespace = local.prometheus_namespace

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
