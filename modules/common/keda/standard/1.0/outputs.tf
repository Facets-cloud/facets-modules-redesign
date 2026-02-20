locals {
  output_attributes = {
    id             = helm_release.keda.id
    release_name   = helm_release.keda.name
    namespace      = helm_release.keda.namespace
    chart_version  = helm_release.keda.version
    release_status = helm_release.keda.status
  }
  output_interfaces = {}
}

