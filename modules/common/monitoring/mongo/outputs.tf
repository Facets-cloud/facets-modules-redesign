locals {
  output_attributes = {
    enabled_alert_count  = length(local.alert_rules)
    namespace            = var.instance.spec.prometheus_namespace
    prometheus_rule_name = local.name
    rule_group_name      = "${var.instance_name}-mongodb-alerts"
    service              = local.mongo_service
  }
  output_interfaces = {
  }
}