locals {
  output_attributes = {
    exporter_enabled        = local.enable_metrics
    exporter_release        = local.enable_metrics ? helm_release.mongodb_exporter[0].name : ""
    exporter_namespace      = local.mongo_namespace
    exporter_chart          = local.enable_metrics ? "prometheus-mongodb-exporter" : ""
    exporter_chart_version  = local.enable_metrics ? helm_release.mongodb_exporter[0].version : ""
    service_monitor_enabled = local.enable_metrics
    prometheus_rule_name    = local.enable_alerts ? "${local.name}-alerts" : ""
    prometheus_namespace    = local.prometheus_namespace
    alerts_enabled          = local.enable_alerts
    enabled_alert_count     = length(local.alert_rules)
    rule_group_name         = "${var.instance_name}-mongodb-alerts"
    dashboard_enabled       = local.enable_dashboard
    dashboard_folder        = lookup(var.instance.spec, "dashboard_folder", "MongoDB")
    mongodb_host            = local.mongo_host
    mongodb_namespace       = local.mongo_namespace
  }

  output_interfaces = {}
}