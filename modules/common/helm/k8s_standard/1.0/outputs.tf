locals {
  output_attributes = {
    release_name = helm_release.external_helm_charts.name
    values       = jsondecode(helm_release.external_helm_charts.metadata[0].values)
  }
  output_interfaces = {}
}
