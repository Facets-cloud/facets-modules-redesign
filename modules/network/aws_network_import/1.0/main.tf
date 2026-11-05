# VPC
resource "aws_vpc" "main" {
  cidr_block           = local.spec.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = local.vpc_name
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = local.vpc_name
  })
}

# Private Subnets (keyed by live subnet id)
resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name                              = "${local.vpc_name}-private-${each.value.az}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# Public Subnets (keyed by live subnet id)
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name                     = "${local.vpc_name}-public-${each.value.az}"
    "kubernetes.io/role/elb" = "1"
  })
}

# Single Elastic IP for the NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.vpc_name}-${local.nat_az}"
  })

  depends_on = [aws_internet_gateway.main]
}

# Single NAT Gateway (in the public subnet of the NAT AZ)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  # reference the public subnet this module owns, not a pinned copy of its id
  subnet_id = aws_subnet.public[local.nat_subnet_id].id

  tags = merge(local.common_tags, {
    Name = "${local.vpc_name}-${local.nat_az}"
  })

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table (0.0.0.0/0 -> IGW)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.vpc_name}-public"
  })
}

# Private Route Table (0.0.0.0/0 -> NAT, peering CIDR -> peering connection)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  route {
    cidr_block = local.peering.cidr
    # reference the peering connection this module owns, not a pinned copy of its id
    vpc_peering_connection_id = aws_vpc_peering_connection.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.vpc_name}-private"
  })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = local.private_subnets

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private.id
}

# Interface VPC Endpoints (explicit list from live)
resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id            = aws_vpc.main.id
  service_name      = each.value.service_name
  vpc_endpoint_type = "Interface"
  # reference the private subnets this module owns, not pinned copies of their ids
  subnet_ids          = [for s in each.value.subnet_ids : aws_subnet.private[s].id]
  security_group_ids  = each.value.security_group_ids
  private_dns_enabled = false

  tags = each.value.tags
}

# Gateway VPC Endpoints (S3) - associated to the private route table
resource "aws_vpc_endpoint" "gateway" {
  for_each = local.gateway_endpoints

  vpc_id            = aws_vpc.main.id
  service_name      = each.value.service_name
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = each.value.tags
}

# Default "allow all from within VPC" security group (owned here, matching the live network module).
resource "aws_security_group" "default" {
  name        = local.default_sg.name
  description = local.default_sg.description
  vpc_id      = aws_vpc.main.id
  tags        = lookup(local.default_sg, "tags", {})

  dynamic "ingress" {
    for_each = lookup(local.default_sg, "ingress", [])
    content {
      from_port        = ingress.value.from_port
      to_port          = ingress.value.to_port
      protocol         = ingress.value.protocol
      cidr_blocks      = lookup(ingress.value, "cidr_blocks", [])
      ipv6_cidr_blocks = lookup(ingress.value, "ipv6_cidr_blocks", [])
      prefix_list_ids  = lookup(ingress.value, "prefix_list_ids", [])
      security_groups  = lookup(ingress.value, "security_groups", [])
      self             = lookup(ingress.value, "self", false)
      description      = lookup(ingress.value, "description", null)
    }
  }
  dynamic "egress" {
    for_each = lookup(local.default_sg, "egress", [])
    content {
      from_port        = egress.value.from_port
      to_port          = egress.value.to_port
      protocol         = egress.value.protocol
      cidr_blocks      = lookup(egress.value, "cidr_blocks", [])
      ipv6_cidr_blocks = lookup(egress.value, "ipv6_cidr_blocks", [])
      prefix_list_ids  = lookup(egress.value, "prefix_list_ids", [])
      security_groups  = lookup(egress.value, "security_groups", [])
      self             = lookup(egress.value, "self", false)
      description      = lookup(egress.value, "description", null)
    }
  }
}

# VPC peering connection (requester side, owned here). The accepter lives in the peer
# account and is managed there (cross-account), so only the requester is imported.
resource "aws_vpc_peering_connection" "main" {
  vpc_id        = aws_vpc.main.id
  peer_vpc_id   = local.peering.peer_vpc_id
  peer_owner_id = local.peering.peer_owner_id
  peer_region   = local.peering.peer_region
  auto_accept   = false
  tags          = lookup(local.peering, "tags", {})
}
