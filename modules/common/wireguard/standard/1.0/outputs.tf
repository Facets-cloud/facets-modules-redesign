locals {
  output_attributes = {
    release_name = helm_release.wireguard_release.name
    namespace    = helm_release.wireguard_release.namespace
    chart        = helm_release.wireguard_release.chart
    version      = helm_release.wireguard_release.version
    status       = helm_release.wireguard_release.status
  }

  output_interfaces = {}
}
