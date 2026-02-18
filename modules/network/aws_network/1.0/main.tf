
# VPC
resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# Public Subnets (one per AZ)
resource "aws_subnet" "public" {
  for_each = {
    for subnet in local.public_subnets :
    subnet.az => subnet
  }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, local.eks_public_tags, {
    Name = "${local.name_prefix}-public-${each.value.az}"
    Type = "Public"
  })
}

# Private Subnets (one per AZ)
resource "aws_subnet" "private" {
  for_each = {
    for subnet in local.private_subnets :
    subnet.az => subnet
  }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.az

  tags = merge(local.common_tags, local.eks_private_tags, {
    Name = "${local.name_prefix}-private-${each.value.az}"
    Type = "Private"
  })

  lifecycle {
    ignore_changes = [
      tags["karpenter.sh/discovery"]
    ]
  }
}

# Database Subnets (one per AZ)
resource "aws_subnet" "database" {
  for_each = {
    for subnet in local.database_subnets :
    subnet.az => subnet
  }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.az

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-database-${each.value.az}"
    Type = "Database"
  })
}

# Database Subnet Group
resource "aws_db_subnet_group" "database" {
  name       = "${local.name_prefix}-database-subnet-group"
  subnet_ids = values(aws_subnet.database)[*].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-database-subnet-group"
  })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  for_each = local.nat_gateway.strategy == "per_az" ? {
    for az in local.selected_azs : az => az
    } : {
    single = local.selected_azs[0]
  }

  tags = merge(local.common_tags, {
    Name = local.nat_gateway.strategy == "per_az" ? "${local.name_prefix}-eip-${each.key}" : "${local.name_prefix}-eip"
  })

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  for_each = local.nat_gateway.strategy == "per_az" ? {
    for az in local.selected_azs : az => az
    } : {
    single = local.selected_azs[0]
  }

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = local.nat_gateway.strategy == "per_az" ? aws_subnet.public[each.key].id : aws_subnet.public[local.selected_azs[0]].id

  tags = merge(local.common_tags, {
    Name = local.nat_gateway.strategy == "per_az" ? "${local.name_prefix}-nat-${each.key}" : "${local.name_prefix}-nat"
  })

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables
resource "aws_route_table" "private" {
  for_each = local.nat_gateway.strategy == "per_az" ? {
    for az in local.selected_azs : az => az
    } : {
    single = "single"
  }

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = local.nat_gateway.strategy == "per_az" ? aws_nat_gateway.main[each.key].id : aws_nat_gateway.main["single"].id
  }

  tags = merge(local.common_tags, {
    Name = local.nat_gateway.strategy == "per_az" ? "${local.name_prefix}-private-rt-${each.key}" : "${local.name_prefix}-private-rt"
  })
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = local.nat_gateway.strategy == "per_az" ? aws_route_table.private[each.value.availability_zone].id : aws_route_table.private["single"].id
}

# Database Route Tables (isolated - no internet access)
resource "aws_route_table" "database" {
  for_each = {
    for az in local.selected_azs : az => az
  }

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-database-rt-${each.key}"
  })
}

# Database Route Table Associations
resource "aws_route_table_association" "database" {
  for_each = aws_subnet.database

  subnet_id      = each.value.id
  route_table_id = aws_route_table.database[each.value.availability_zone].id
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  count = anytrue([
    try(local.vpc_endpoints.enable_ecr_api, false),
    try(local.vpc_endpoints.enable_ecr_dkr, false),
    try(local.vpc_endpoints.enable_eks, false),
    try(local.vpc_endpoints.enable_ec2, false),
    try(local.vpc_endpoints.enable_ssm, false),
    try(local.vpc_endpoints.enable_ssm_messages, false),
    try(local.vpc_endpoints.enable_ec2_messages, false),
    try(local.vpc_endpoints.enable_kms, false),
    try(local.vpc_endpoints.enable_logs, false),
    try(local.vpc_endpoints.enable_monitoring, false),
    try(local.vpc_endpoints.enable_sts, false),
    try(local.vpc_endpoints.enable_lambda, false)
  ]) ? 1 : 0

  name_prefix = "${local.name_prefix}-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.instance.spec.vpc_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-endpoints-sg"
  })
}

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  count = try(local.vpc_endpoints.enable_s3, false) ? 1 : 0

  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.inputs.cloud_account.attributes.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    values(aws_route_table.private)[*].id,
    values(aws_route_table.database)[*].id
  )

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-s3-endpoint"
  })
}

# DynamoDB Gateway Endpoint
resource "aws_vpc_endpoint" "dynamodb" {
  count = try(local.vpc_endpoints.enable_dynamodb, false) ? 1 : 0

  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.inputs.cloud_account.attributes.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    values(aws_route_table.private)[*].id,
    values(aws_route_table.database)[*].id
  )

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-dynamodb-endpoint"
  })
}

# ECR API Interface Endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  count = try(local.vpc_endpoints.enable_ecr_api, false) ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.inputs.cloud_account.attributes.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecr-api-endpoint"
  })
}

# ECR Docker Interface Endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  count = try(local.vpc_endpoints.enable_ecr_dkr, false) ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.inputs.cloud_account.attributes.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ecr-dkr-endpoint"
  })
}

# EKS Interface Endpoint
resource "aws_vpc_endpoint" "eks" {
  count = try(local.vpc_endpoints.enable_eks, false) ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.inputs.cloud_account.attributes.aws_region}.eks"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eks-endpoint"
  })
}

# EC2 Interface Endpoint
resource "aws_vpc_endpoint" "ec2" {
  count = try(local.vpc_endpoints.enable_ec2, false) ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.inputs.cloud_account.attributes.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ec2-endpoint"
  })
}

# SSM Interface Endpoint
resource "aws_vpc_endpoint" "ssm" {
  count = try(local.vpc_endpoints.enable_ssm, false) ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.inputs.cloud_account.attributes.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ssm-endpoint"
  })
}

# SSM Messages Interface Endpoint
resource "aws_vpc_endpoint" "ssm_messages" {
  count = try(local.vpc_endpoints.enable_ssm_messages, false) ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.inputs.cloud_account.attributes.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ssm-messages-endpoint"
  })
}

# EC2 Messages Interface Endpoint
resource "aws_vpc_endpoint" "ec2_messages" {
  count = try(local.vpc_endpoints.enable_ec2_messages, false) ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.inputs.cloud_account.attributes.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ec2-messages-endpoint"
  })
}

# KMS Interface Endpoint
resource "aws_vpc_endpoint" "kms" {
  count = try(local.vpc_endpoints.enable_kms, false) ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.inputs.cloud_account.attributes.aws_region}.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-kms-endpoint"
  })
}

# CloudWatch Logs Interface Endpoint
resource "aws_vpc_endpoint" "logs" {
  count = try(local.vpc_endpoints.enable_logs, false) ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.inputs.cloud_account.attributes.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-logs-endpoint"
  })
}

# CloudWatch Monitoring Interface Endpoint
resource "aws_vpc_endpoint" "monitoring" {
  count = try(local.vpc_endpoints.enable_monitoring, false) ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.inputs.cloud_account.attributes.aws_region}.monitoring"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-monitoring-endpoint"
  })
}

# STS Interface Endpoint
resource "aws_vpc_endpoint" "sts" {
  count = try(local.vpc_endpoints.enable_sts, false) ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.inputs.cloud_account.attributes.aws_region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sts-endpoint"
  })
}

# Lambda Interface Endpoint
resource "aws_vpc_endpoint" "lambda" {
  count = try(local.vpc_endpoints.enable_lambda, false) ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.inputs.cloud_account.attributes.aws_region}.lambda"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.private)[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-lambda-endpoint"
  })
}
