locals {
  output_attributes = {
    namespace     = local.namespace
    release_name  = helm_release.mongodb_operator.name
    chart_version = helm_release.mongodb_operator.version
    operator_name = "mongodb-kubernetes-operator"
    repository    = local.repository
    chart_name    = local.chart_name
    status        = helm_release.mongodb_operator.status
    revision      = helm_release.mongodb_operator.metadata[0].revision
  }
}
output "output_attributes" {
  value = local.output_attributes
}