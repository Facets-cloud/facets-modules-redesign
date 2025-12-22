locals {
  output_attributes = {
    release_name = helm_release.wireguard_vpn.name
    namespace    = helm_release.wireguard_vpn.namespace
    chart        = helm_release.wireguard_vpn.chart
    version      = helm_release.wireguard_vpn.version
    status       = helm_release.wireguard_vpn.status
  }
  output_interfaces = {
  }
}