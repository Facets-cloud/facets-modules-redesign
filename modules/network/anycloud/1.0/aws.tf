# AWS branch — Kubernetes-optimized VPC. All resources count/for_each-gated on the linked
# account resolving to AWS. Subnets auto-calculated in locals.tf (private/public/database per AZ).

data "aws_availability_zones" "available" {
  count = local.is_aws ? 1 : 0
  state = "available"
}

resource "aws_vpc" "main" {
  count                = local.is_aws ? 1 : 0
  cidr_block           = local.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  count  = local.is_aws ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# Public subnets (one per AZ) — tagged for external ELBs
resource "aws_subnet" "public" {
  for_each = local.is_aws ? { for s in local.aws_public_subnets : s.az => s } : {}

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, local.eks_public_tags, {
    Name = "${local.name_prefix}-public-${each.value.az}"
    Type = "Public"
  })
}

# Private subnets (one per AZ) — tagged for internal ELBs; Karpenter discovery tag ignored
resource "aws_subnet" "private" {
  for_each = local.is_aws ? { for s in local.aws_private_subnets : s.az => s } : {}

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.az

  tags = merge(local.common_tags, local.eks_private_tags, {
    Name = "${local.name_prefix}-private-${each.value.az}"
    Type = "Private"
  })

  lifecycle {
    ignore_changes = [tags["karpenter.sh/discovery"]]
  }
}

# Database subnets (one per AZ)
resource "aws_subnet" "database" {
  for_each = local.is_aws ? { for s in local.aws_database_subnets : s.az => s } : {}

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.az

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-database-${each.value.az}"
    Type = "Database"
  })
}

resource "aws_db_subnet_group" "database" {
  count      = local.is_aws ? 1 : 0
  name       = "${local.name_prefix}-database-subnet-group"
  subnet_ids = values(aws_subnet.database)[*].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-database-subnet-group"
  })
}

# Elastic IPs for NAT Gateways (single, or one per AZ)
resource "aws_eip" "nat" {
  for_each = local.is_aws ? (local.aws_nat_strategy == "per_az" ? {
    for az in local.aws_selected_azs : az => az
    } : {
    single = local.aws_selected_azs[0]
  }) : {}

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = local.aws_nat_strategy == "per_az" ? "${local.name_prefix}-eip-${each.key}" : "${local.name_prefix}-eip"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  for_each = local.is_aws ? (local.aws_nat_strategy == "per_az" ? {
    for az in local.aws_selected_azs : az => az
    } : {
    single = local.aws_selected_azs[0]
  }) : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = local.aws_nat_strategy == "per_az" ? aws_subnet.public[each.key].id : aws_subnet.public[local.aws_selected_azs[0]].id

  tags = merge(local.common_tags, {
    Name = local.aws_nat_strategy == "per_az" ? "${local.name_prefix}-nat-${each.key}" : "${local.name_prefix}-nat"
  })

  depends_on = [aws_internet_gateway.main]
}

# Public route table -> IGW
resource "aws_route_table" "public" {
  count  = local.is_aws ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}

# Private route tables -> NAT (single or per AZ)
resource "aws_route_table" "private" {
  for_each = local.is_aws ? (local.aws_nat_strategy == "per_az" ? {
    for az in local.aws_selected_azs : az => az
    } : {
    single = "single"
  }) : {}

  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = local.aws_nat_strategy == "per_az" ? aws_nat_gateway.main[each.key].id : aws_nat_gateway.main["single"].id
  }

  tags = merge(local.common_tags, {
    Name = local.aws_nat_strategy == "per_az" ? "${local.name_prefix}-private-rt-${each.key}" : "${local.name_prefix}-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = local.aws_nat_strategy == "per_az" ? aws_route_table.private[each.value.availability_zone].id : aws_route_table.private["single"].id
}

# Database route tables (isolated — no internet route)
resource "aws_route_table" "database" {
  for_each = local.is_aws ? { for az in local.aws_selected_azs : az => az } : {}
  vpc_id   = aws_vpc.main[0].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-database-rt-${each.key}"
  })
}

resource "aws_route_table_association" "database" {
  for_each       = aws_subnet.database
  subnet_id      = each.value.id
  route_table_id = aws_route_table.database[each.value.availability_zone].id
}

# ───────── VPC Endpoints ─────────
resource "aws_security_group" "vpc_endpoints" {
  count = local.is_aws && local.aws_any_interface_endpoint ? 1 : 0

  name_prefix = "${local.name_prefix}-vpc-endpoints"
  description = "Security group for VPC interface endpoints"
  vpc_id      = aws_vpc.main[0].id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.cidr]
  }

  # Interface endpoints only answer requests from inside the VPC; no internet egress needed.
  egress {
    description = "Outbound within the VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.cidr]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-endpoints-sg"
  })
}

# Gateway endpoints (free) — routed through all route tables
resource "aws_vpc_endpoint" "s3" {
  count             = local.is_aws && local.aws_vpc_endpoints.enable_s3 ? 1 : 0
  vpc_id            = aws_vpc.main[0].id
  service_name      = "com.amazonaws.${local.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.public[0].id], values(aws_route_table.private)[*].id, values(aws_route_table.database)[*].id)
  tags              = merge(local.common_tags, { Name = "${local.name_prefix}-s3-endpoint" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  count             = local.is_aws && local.aws_vpc_endpoints.enable_dynamodb ? 1 : 0
  vpc_id            = aws_vpc.main[0].id
  service_name      = "com.amazonaws.${local.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.public[0].id], values(aws_route_table.private)[*].id, values(aws_route_table.database)[*].id)
  tags              = merge(local.common_tags, { Name = "${local.name_prefix}-dynamodb-endpoint" })
}

# Interface endpoints — in private subnets, behind the endpoints SG
locals {
  aws_interface_endpoints = {
    ecr_api      = { enabled = local.aws_vpc_endpoints.enable_ecr_api, service = "ecr.api" }
    ecr_dkr      = { enabled = local.aws_vpc_endpoints.enable_ecr_dkr, service = "ecr.dkr" }
    eks          = { enabled = local.aws_vpc_endpoints.enable_eks, service = "eks" }
    ec2          = { enabled = local.aws_vpc_endpoints.enable_ec2, service = "ec2" }
    ssm          = { enabled = local.aws_vpc_endpoints.enable_ssm, service = "ssm" }
    ssm_messages = { enabled = local.aws_vpc_endpoints.enable_ssm_messages, service = "ssmmessages" }
    ec2_messages = { enabled = local.aws_vpc_endpoints.enable_ec2_messages, service = "ec2messages" }
    kms          = { enabled = local.aws_vpc_endpoints.enable_kms, service = "kms" }
    logs         = { enabled = local.aws_vpc_endpoints.enable_logs, service = "logs" }
    monitoring   = { enabled = local.aws_vpc_endpoints.enable_monitoring, service = "monitoring" }
    sts          = { enabled = local.aws_vpc_endpoints.enable_sts, service = "sts" }
    lambda       = { enabled = local.aws_vpc_endpoints.enable_lambda, service = "lambda" }
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.is_aws ? { for k, v in local.aws_interface_endpoints : k => v if v.enabled } : {}

  vpc_id              = aws_vpc.main[0].id
  service_name        = "com.amazonaws.${local.aws_region}.${each.value.service}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-${each.key}-endpoint" })
}
