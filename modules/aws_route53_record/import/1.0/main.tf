# Route53 records (imported; attributes from live), keyed by name.
resource "aws_route53_record" "main" {
  for_each = local.records

  zone_id = each.value.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.ttl
  records = each.value.records
}
