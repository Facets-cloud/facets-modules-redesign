locals {
  output_attributes = {
    alert_count          = length(local.rule_names)
    alert_names          = local.rule_names
    namespace            = var.environment.namespace
    prometheus_rule_name = "${var.instance_name}-alert-group"
  }
  output_interfaces = {}
}
