locals {
  output_interfaces = {}
  output_attributes = {
    zone_name    = local.managed_zone_name
    dns_name     = local.dns_name
    name_servers = local.create_zone ? google_dns_managed_zone.this[0].name_servers : []
  }
}
