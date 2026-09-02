terraform {
  required_version = ">= 1.0"
}

resource "google_dns_managed_zone" "this" {
  count       = local.create_zone ? 1 : 0
  project     = local.project_id
  name        = local.zone_name
  dns_name    = local.dns_name
  description = local.description
  visibility  = local.visibility

  dynamic "private_visibility_config" {
    for_each = local.visibility == "private" ? [1] : []

    content {
      dynamic "networks" {
        for_each = toset(local.network_self_links)

        content {
          network_url = networks.value
        }
      }
    }
  }

  dynamic "dnssec_config" {
    for_each = local.visibility == "private" ? [] : [1]

    content {
      state = local.dnssec
    }
  }
}

resource "google_dns_record_set" "this" {
  for_each     = local.records
  project      = local.project_id
  managed_zone = local.managed_zone_name
  name         = each.value.fqdn
  type         = each.value.type
  ttl          = each.value.ttl
  rrdatas      = each.value.rrdatas
}
