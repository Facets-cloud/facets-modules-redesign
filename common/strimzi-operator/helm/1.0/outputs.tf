locals {
  output_attributes = {
    namespace     = local.namespace
    release_name  = helm_release.strimzi_operator.name
    chart_version = helm_release.strimzi_operator.version
    operator_name = "strimzi-cluster-operator"
    repository    = local.repository
    chart_name    = local.chart_name
    status        = helm_release.strimzi_operator.status
    revision      = helm_release.strimzi_operator.metadata[0].revision
  }
}
output "output_attributes" {
  value = local.output_attributes
}