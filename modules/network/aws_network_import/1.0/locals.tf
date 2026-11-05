# Import-faithful network: every attribute is driven by the live spec (pushed as
# an env override) so a plan against the live VPC is 0-change. See facets.yaml.
locals {
  spec        = var.instance.spec
  common_tags = local.spec.common_tags
  vpc_name    = local.spec.vpc_name

  subnets         = { for s in local.spec.subnets : s.id => s }
  private_subnets = { for k, s in local.subnets : k => s if s.role == "private" }
  public_subnets  = { for k, s in local.subnets : k => s if s.role == "public" }

  nat_subnet_id = local.spec.nat_subnet_id
  nat_az        = local.subnets[local.nat_subnet_id].az

  peering    = local.spec.peering
  default_sg = local.spec.default_security_group

  endpoints           = { for e in local.spec.endpoints : e.key => e }
  interface_endpoints = { for k, e in local.endpoints : k => e if e.type == "Interface" }
  gateway_endpoints   = { for k, e in local.endpoints : k => e if e.type == "Gateway" }
}
