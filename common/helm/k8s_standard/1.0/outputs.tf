locals {
  output_attributes = {
    release_name = helm_release.external_helm_charts.name
    values       = helm_release.external_helm_charts.metadata[0].values
  }
  output_interfaces = {}
}

output "metadata" {
  value = helm_release.external_helm_charts.metadata
}
output "status" {
  value = helm_release.external_helm_charts.status
}
