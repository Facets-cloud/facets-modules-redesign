locals {
  output_attributes = {
    release_name      = helm_release.git_chart.name
    release_namespace = helm_release.git_chart.namespace
    chart_version     = helm_release.git_chart.version
    helm_release_id   = helm_release.git_chart.id
  }
  output_interfaces = {}
}
