locals {
  output_attributes = {
    exporter_enabled        = local.enable_metrics
    exporter_release        = local.enable_metrics ? helm_release.postgres_exporter[0].name : ""
    exporter_namespace      = local.postgres_namespace
    exporter_chart          = local.enable_metrics ? "prometheus-postgres-exporter" : ""
    exporter_chart_version  = local.enable_metrics ? helm_release.postgres_exporter[0].version : ""
    service_monitor_enabled = local.enable_metrics
    prometheus_rule_name    = local.enable_alerts ? "${local.name}-alerts" : ""
    prometheus_namespace    = local.prometheus_namespace
    alerts_enabled          = local.enable_alerts
    enabled_alert_count     = length(local.alert_rules)
    rule_group_name         = "${var.instance_name}-postgresql-alerts"
  }
  output_interfaces = {}
}
