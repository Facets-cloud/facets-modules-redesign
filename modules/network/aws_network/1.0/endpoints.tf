# ───────────────────────── VPC endpoints ──────────────────────────────────
# Two collections, both keyed so import ids map cleanly:
#   aws_vpc_endpoint.gateway["s3"]        gateway endpoints (free, route-table attached)
#   aws_vpc_endpoint.interface["sqs"]     AWS interface endpoints
#   aws_vpc_endpoint.custom["privatelink-1"]  non-AWS PrivateLink services

resource "aws_security_group" "vpc_endpoints" {
  count = local.create_endpoint_sg ? 1 : 0

  name        = "${local.name_prefix}-vpc-endpoints"
  description = "Allow HTTPS from within the VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpc-endpoints" })
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = local.gateway_endpoints

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${local.aws_region}.${each.key}"
  vpc_endpoint_type = "Gateway"

  # Default: attach to every route table in the plan. An adopted endpoint pins
  # the exact set it already carries.
  route_table_ids = contains(keys(local.ep_ovr_rtbs), each.key) ? [
    for k in local.ep_ovr_rtbs[each.key] : aws_route_table.this[k].id
  ] : [for k, rt in local.route_tables : aws_route_table.this[k].id]

  tags = contains(keys(local.ep_ovr_tags), each.key) ? local.ep_ovr_tags[each.key] : merge(
    local.common_tags, { Name = "${local.name_prefix}-${each.key}-endpoint" }
  )
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${local.aws_region}.${local.ep_service_name[each.key]}"
  vpc_endpoint_type = "Interface"

  # Default: every private subnet, the module SG, private DNS on. An adopted
  # endpoint pins whichever of those live differs - which in practice is all
  # three, because these were placed by hand.
  subnet_ids = contains(keys(local.ep_ovr_subnets), each.key) ? [
    for k in local.ep_ovr_subnets[each.key] : aws_subnet.this[k].id
  ] : [for k in local.private_subnet_keys : aws_subnet.this[k].id]

  security_group_ids = contains(keys(local.ep_ovr_sgs), each.key) ? (
    local.ep_ovr_sgs[each.key]
  ) : (local.create_endpoint_sg ? [aws_security_group.vpc_endpoints[0].id] : [])

  private_dns_enabled = lookup(local.ep_ovr_dns, each.key, true)

  tags = contains(keys(local.ep_ovr_tags), each.key) ? local.ep_ovr_tags[each.key] : merge(
    local.common_tags, { Name = "${local.name_prefix}-${each.key}-endpoint" }
  )
}

resource "aws_vpc_endpoint" "custom" {
  for_each = local.custom_endpoints

  vpc_id            = aws_vpc.this.id
  service_name      = each.value.service_name
  vpc_endpoint_type = lookup(each.value, "endpoint_type", "Interface")

  subnet_ids = [
    for k in lookup(each.value, "subnet_keys", []) : aws_subnet.this[k].id
  ]
  route_table_ids = [
    for k in lookup(each.value, "route_table_keys", []) : aws_route_table.this[k].id
  ]

  # An adopted endpoint keeps the security groups it already has. Falling back to
  # the module SG only happens when the entry names none and one exists.
  security_group_ids = length(lookup(each.value, "security_group_ids", [])) > 0 ? (
    each.value.security_group_ids
  ) : (local.create_endpoint_sg ? [aws_security_group.vpc_endpoints[0].id] : [])

  private_dns_enabled = lookup(each.value, "private_dns_enabled", false)

  tags = lookup(each.value, "tags", null) != null ? each.value.tags : merge(
    local.common_tags, { Name = "${local.name_prefix}-${each.key}" }
  )
}
