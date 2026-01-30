locals {
  output_attributes = {
    prometheus_rule_name = "${local.name}-rules"
    namespace            = local.namespace
    alert_group_names    = local.alert_group_names
    prometheus_release   = local.prometheus_release
  }

  output_interfaces = {}
}
