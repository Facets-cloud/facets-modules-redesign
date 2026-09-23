locals {
  output_attributes = {
    load_balancer_arn  = aws_lb.ecs_alb.arn
    load_balancer_dns  = aws_lb.ecs_alb.dns_name
    load_balancer_zone = aws_lb.ecs_alb.zone_id
  }
  output_interfaces = {
    for rule_key, rule in var.instance.spec.rules : "facets-${rule_key}" => {
      connection_string = "https://${lookup(rule, "domain_prefix", "") != "" ? "${lookup(rule, "domain_prefix", "")}." : ""}${var.instance.spec.domain}"
      host              = "${lookup(rule, "domain_prefix", "") != "" ? "${lookup(rule, "domain_prefix", "")}." : ""}${var.instance.spec.domain}"
      port              = 443
      username          = ""
      password          = ""
    }
  }
}
