locals {
  name = var.instance_name

  # Always use prometheus namespace for PrometheusRule deployment
  namespace = lookup(var.inputs.prometheus.attributes, "namespace", var.environment.namespace)

  prometheus_release = lookup(var.inputs.prometheus.attributes, "prometheus_release", "prometheus")

  # Transform alert_groups from spec into PrometheusRule groups
  alert_groups = [
    for group_name, group_config in var.instance.spec.alert_groups : {
      name = group_name

      rules = [
        for rule_name, rule_config in group_config.rules : {
          alert = rule_name
          expr  = rule_config.expression
          for   = lookup(rule_config, "duration", "5m")

          # Standardized alert labels following Facets conventions
          # User labels merged first, then system labels (matching alert_group_helm pattern)
          labels = merge(
            lookup(rule_config, "labels", {}),
            local.common_labels,
            {
              severity      = lookup(rule_config, "severity", "warning")
              alert_type    = rule_name
              namespace     = local.namespace
              alert_group   = group_name
              resource_type = lookup(rule_config, "resource_type", null)
              resource_name = lookup(rule_config, "resource_name", null)
              resourceType  = lookup(rule_config, "resource_type", null)
              resourceName  = lookup(rule_config, "resource_name", null)
            }
          )

          annotations = merge(
            {
              summary     = rule_config.summary
              description = lookup(rule_config, "description", "")
            },
            lookup(rule_config, "annotations", {})
          )
        } if !lookup(rule_config, "disabled", false) # Filter out disabled rules
      ]
    }
  ]

  # Statistics for outputs
  total_alert_count = sum([for group in local.alert_groups : length(group.rules)])
  alert_group_count = length(local.alert_groups)
  alert_group_names = join(", ", [for group in local.alert_groups : group.name])

  # Labels for PrometheusRule (must include release for discovery)
  common_labels = {
    "app.kubernetes.io/name"       = "alert-rules"
    "app.kubernetes.io/instance"   = var.instance_name
    "app.kubernetes.io/managed-by" = "facets"
    "facets.cloud/environment"     = var.environment.name
    "release"                      = local.prometheus_release # CRITICAL for Prometheus Operator discovery
  }
}
