locals {
  output_attributes = {
    prometheus_rule_name = "${local.name}-rules"
    namespace            = local.namespace
    alerts_enabled       = "true"
    total_alert_count    = tostring(local.total_alert_count)
    alert_group_count    = tostring(local.alert_group_count)
    alert_group_names    = local.alert_group_names
    evaluation_interval  = local.evaluation_interval
    prometheus_release   = local.prometheus_release
  }

  output_interfaces = {}
}
