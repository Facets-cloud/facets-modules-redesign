# ─────────────────────────────── VPC ──────────────────────────────────────
resource "aws_vpc" "this" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = lookup(local.spec, "vpc_tags", null) != null ? local.spec.vpc_tags : merge(
    local.common_tags, { Name = local.name_prefix }
  )

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = lookup(local.spec, "internet_gateway_tags", null) != null ? local.spec.internet_gateway_tags : merge(
    local.common_tags, { Name = "${local.name_prefix}-igw" }
  )
}

# ────────────────────────────── Subnets ───────────────────────────────────
# ONE resource, keyed by an explicit plan key. Never keyed by AZ - the same AZ
# may hold several subnets of the same tier.
resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = each.value.map_public_ip_on_launch

  # Declared tags are used verbatim with no merge - an empty map is a legal
  # value meaning "this subnet genuinely has no tags".
  tags = each.value.tags != null ? each.value.tags : merge(
    local.common_tags,
    each.value.tier == "public" ? local.eks_public_tags : {},
    each.value.tier == "private" ? local.eks_private_tags : {},
    {
      Name = each.value.name != null ? each.value.name : "${local.name_prefix}-${each.value.tier}-${each.value.availability_zone}"
      Type = title(each.value.tier)
    },
  )

  lifecycle {
    ignore_changes = [tags["karpenter.sh/discovery"]]
  }
}

resource "aws_db_subnet_group" "database" {
  count = length(local.database_subnet_keys) > 0 ? 1 : 0

  name       = "${local.name_prefix}-database"
  subnet_ids = [for k in local.database_subnet_keys : aws_subnet.this[k].id]

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-database" })
}

# ──────────────────────────── NAT gateways ────────────────────────────────
resource "aws_eip" "nat" {
  for_each = local.nat_gateways

  domain = "vpc"

  tags = each.value.eip_tags != null ? each.value.eip_tags : merge(
    local.common_tags, { Name = "${local.name_prefix}-nat-eip-${each.key}" }
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = local.nat_gateways

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.this[each.value.subnet_key].id

  tags = each.value.tags != null ? each.value.tags : merge(
    local.common_tags,
    { Name = each.value.name != null ? each.value.name : "${local.name_prefix}-nat-${each.key}" }
  )

  depends_on = [aws_internet_gateway.this]
}

# ──────────────────────────── Route tables ────────────────────────────────
# No inline `route` blocks. Inline routes are authoritative and would delete any
# route this module does not declare - including peering routes owned elsewhere.
resource "aws_route_table" "this" {
  for_each = local.route_tables

  vpc_id = aws_vpc.this.id

  tags = each.value.tags != null ? each.value.tags : merge(
    local.common_tags,
    { Name = each.value.name != null ? each.value.name : "${local.name_prefix}-rt-${each.key}" }
  )
}

resource "aws_route" "this" {
  for_each = local.routes

  route_table_id         = aws_route_table.this[each.value.route_table_key].id
  destination_cidr_block = each.value.destination

  gateway_id     = each.value.target_type == "internet_gateway" ? aws_internet_gateway.this.id : null
  nat_gateway_id = each.value.target_type == "nat_gateway" ? aws_nat_gateway.this[each.value.nat_gateway_key].id : null
}

resource "aws_route_table_association" "this" {
  for_each = local.subnet_associations

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.value.route_table_key].id
}

# E4: greenfield-only. Main-ness pre-exists on an adopted VPC and the resource is
# not importable; flapping the main table on a live VPC is the highest-blast-radius
# change available here. In a NEW VPC it is required, otherwise subnets with
# associate_route_table=false would inherit a fresh empty main table and blackhole.
resource "aws_main_route_table_association" "this" {
  count = (!local.importing && local.main_route_table_key != null) ? 1 : 0

  vpc_id         = aws_vpc.this.id
  route_table_id = aws_route_table.this[local.main_route_table_key].id
}

# ─────────────────────────── Network ACL ──────────────────────────────────
# Opt-in. Declaring rules makes Terraform the owner of the default ACL's rules.
resource "aws_default_network_acl" "this" {
  count = local.manage_nacl ? 1 : 0

  default_network_acl_id = aws_vpc.this.default_network_acl_id

  dynamic "ingress" {
    for_each = local.nacl_ingress
    content {
      rule_no    = ingress.value.rule_number
      action     = ingress.value.action
      protocol   = ingress.value.protocol
      cidr_block = ingress.value.cidr_block
      from_port  = ingress.value.from_port
      to_port    = ingress.value.to_port
    }
  }

  dynamic "egress" {
    for_each = local.nacl_egress
    content {
      rule_no    = egress.value.rule_number
      action     = egress.value.action
      protocol   = egress.value.protocol
      cidr_block = egress.value.cidr_block
      from_port  = egress.value.from_port
      to_port    = egress.value.to_port
    }
  }

  tags = try(local.nacl_spec.tags, null) != null ? local.nacl_spec.tags : merge(
    local.common_tags, { Name = "${local.name_prefix}-default-nacl" }
  )

  # Subnet membership of the default ACL is implicit in AWS - every subnet not
  # explicitly placed elsewhere lands here. Managing it would fight AWS.
  lifecycle {
    ignore_changes = [subnet_ids]
  }
}
