locals {
  output_attributes = {
    namespace     = local.namespace
    release_name  = helm_release.k8ssandra_operator.name
    release_id    = helm_release.k8ssandra_operator.id
    chart_version = helm_release.k8ssandra_operator.version
    operator_name = "k8ssandra-operator"
    repository    = local.repository
    chart_name    = local.chart_name
    status        = helm_release.k8ssandra_operator.status
  }
  output_interfaces = {}
}
