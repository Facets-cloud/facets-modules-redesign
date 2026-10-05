locals {
  output_attributes = {
    alert_group_names    = [for g in lookup(lookup(local.values, "content", {}), "groups", []) : g.name]
    namespace            = helm_release.main.namespace
    prometheus_release   = lookup(local.values, "prometheusId", "")
    prometheus_rule_name = helm_release.main.name
  }
  output_interfaces = {}
}
