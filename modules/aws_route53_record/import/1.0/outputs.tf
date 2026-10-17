locals {
  output_attributes = {
    fqdns = join(",", sort([for r in aws_route53_record.main : r.fqdn]))
  }
  output_interfaces = {}
}
