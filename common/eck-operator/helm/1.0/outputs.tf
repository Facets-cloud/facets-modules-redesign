locals {
  output_attributes = {
    namespace       = local.namespace
    release_name    = helm_release.eck_operator.name
    chart_version   = helm_release.eck_operator.version
    operator_name   = "elastic-operator"
    repository      = local.repository
    chart_name      = local.chart_name
    webhook_enabled = true
    status          = helm_release.eck_operator.status
    revision        = helm_release.eck_operator.metadata[0].revision
  }
}
output "output_attributes" {
  value = local.output_attributes
}