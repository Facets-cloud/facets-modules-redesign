locals {
  name = var.instance_name

  # Always use prometheus namespace for PrometheusRule deployment
  namespace = lookup(var.inputs.prometheus.attributes, "namespace", var.environment.namespace)

  evaluation_interval = lookup(var.instance.spec.resources, "evaluation_interval", "30s")
  prometheus_release  = lookup(var.inputs.prometheus.attributes, "prometheus_release", "prometheus")

  # Transform alert_groups from spec into PrometheusRule groups
  alert_groups = [
    for group_name, group_config in var.instance.spec.alert_groups : {
      name     = group_name
      interval = lookup(group_config, "interval", local.evaluation_interval)

      rules = [
        for rule_name, rule_config in group_config.rules : {
          alert = rule_name
          expr  = rule_config.expression
          for   = rule_config.duration

          # Standardized alert labels following Facets conventions
          labels = merge(
            local.common_labels,
            {
              severity             = rule_config.severity
              alert_type           = rule_name
              facets_resource_type = "alert_rules"
              facets_resource_name = var.instance_name
              namespace            = local.namespace
              alert_group          = group_name
            },
            rule_config.labels
          )

          annotations = merge(
            {
              summary     = rule_config.summary
              description = rule_config.description
            },
            rule_config.runbook_url != "" ? { runbook_url = rule_config.runbook_url } : {},
            rule_config.annotations
          )
        }
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
