locals {
  default_cidr = lookup(var.instance.spec, "source_cidr", "")
  rules        = lookup(var.instance.spec, "rules", {})
}

# ONE rule per resource. aws_vpc_security_group_ingress_rule never reads the
# group's other rules into state, so rules created outside Terraform can never
# be proposed for deletion. aws_security_group with inline ingress would own the
# whole group and delete everything not declared here.
resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = local.rules

  security_group_id = each.value.security_group_id
  cidr_ipv4         = coalesce(lookup(each.value, "cidr", null), local.default_cidr)
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = "tcp"
  description       = coalesce(lookup(each.value, "description", null), "facets transfer: ${each.key}")

  tags = {
    Name       = "${var.environment.unique_name}-${each.key}"
    managed-by = "facets"
    intent     = var.instance.kind
  }
}
