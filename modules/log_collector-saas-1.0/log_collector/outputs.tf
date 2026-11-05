locals {
  output_interfaces = {}
  output_attributes = {
    gateway = {
      domain = aws_route53_record.loki_gateway[*].fqdn
    }
  }
}
