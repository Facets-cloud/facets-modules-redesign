locals {
  spec               = var.instance.spec
  project_id         = lookup(local.spec, "project_id_override", "") != "" ? local.spec.project_id_override : var.inputs.network.attributes.project_id
  zone_name          = var.instance.spec.zone_name
  dns_name           = endswith(var.instance.spec.dns_name, ".") ? var.instance.spec.dns_name : "${var.instance.spec.dns_name}."
  description        = lookup(var.instance.spec, "description", "")
  visibility         = lookup(var.instance.spec, "visibility", "public")
  dnssec             = lookup(var.instance.spec, "dnssec", "off")
  network_self_links = length(lookup(local.spec, "network_self_links", [])) > 0 ? local.spec.network_self_links : [var.inputs.network.attributes.vpc_self_link]
  create_zone        = lookup(local.spec, "existing_zone_id", "") == ""
  managed_zone_name  = local.create_zone ? google_dns_managed_zone.this[0].name : local.spec.existing_zone_id

  raw_records = lookup(local.spec, "records", {})
  records = {
    for key, record in local.raw_records : key => {
      fqdn = record.name == "" || record.name == "@" ? local.dns_name : "${record.name}.${local.dns_name}"
      type = upper(record.type)
      ttl  = lookup(record, "ttl", 300)
      rrdatas = [
        for value in length(lookup(record, "values", [])) > 0 ? record.values : [record.value] :
        upper(record.type) == "CNAME" && !endswith(value, ".") ? "${value}." : value
      ]
    }
  }
}
