locals {
  output_attributes = {
    release_name = helm_release.wireguard_operator.name
    namespace    = helm_release.wireguard_operator.namespace
    chart        = helm_release.wireguard_operator.chart
    version      = helm_release.wireguard_operator.version
    status       = helm_release.wireguard_operator.status
  }
  output_interfaces = {
  }
}