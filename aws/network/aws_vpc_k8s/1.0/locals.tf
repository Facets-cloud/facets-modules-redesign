# Data source to get all available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Local values for simplified K8s-optimized calculations
locals {
  # Extract commonly used values to avoid repeated lookups
  spec               = var.instance.spec
  auto_select_azs    = lookup(local.spec, "auto_select_azs", true)
  availability_zones = lookup(local.spec, "availability_zones", [])
  vpc_cidr           = local.spec.vpc_cidr
  nat_gateway        = local.spec.nat_gateway
  vpc_endpoints_spec = lookup(local.spec, "vpc_endpoints", null)
  tags_spec          = lookup(local.spec, "tags", {})
  aws_region         = var.inputs.cloud_account.attributes.aws_region

  # Determine which availability zones to use
  selected_azs = local.auto_select_azs ? (
    length(data.aws_availability_zones.available.names) >= 3 ?
    slice(data.aws_availability_zones.available.names, 0, 3) :
    data.aws_availability_zones.available.names
  ) : local.availability_zones

  # Validate AZ count (2-5 AZs supported)
  num_azs           = length(local.selected_azs)
  validate_az_count = local.num_azs >= 2 && local.num_azs <= 5 ? true : tobool("Number of AZs must be between 2 and 5 for /16 VPC")

  # Fixed subnet allocation for K8s-optimized VPC
  # VPC: /16 (65,536 IPs)
  # Private: /19 per AZ (8,192 IPs) - for K8s pods + nodes + AWS services
  # Public: /24 per AZ (256 IPs) - for NAT + ALB
  # Database: /24 per AZ (256 IPs) - for RDS + managed databases
  vpc_prefix             = 16
  private_subnet_prefix  = 19 # 8,192 IPs per AZ
  public_subnet_prefix   = 24 # 256 IPs per AZ
  database_subnet_prefix = 24 # 256 IPs per AZ

  # Calculate newbits for cidrsubnets function
  private_newbits  = local.private_subnet_prefix - local.vpc_prefix  # 19 - 16 = 3
  public_newbits   = local.public_subnet_prefix - local.vpc_prefix   # 24 - 16 = 8
  database_newbits = local.database_subnet_prefix - local.vpc_prefix # 24 - 16 = 8

  # Create ordered list of newbits for cidrsubnets function
  # Order: private subnets, public subnets, database subnets
  all_subnet_newbits = concat(
    [for i in range(local.num_azs) : local.private_newbits], # Private subnets
    [for i in range(local.num_azs) : local.public_newbits],  # Public subnets
    [for i in range(local.num_azs) : local.database_newbits] # Database subnets
  )

  # Generate all subnet CIDRs using cidrsubnets function - prevents overlaps
  all_subnet_cidrs = cidrsubnets(local.vpc_cidr, local.all_subnet_newbits...)

  # Extract subnet CIDRs by type
  private_subnet_cidrs  = slice(local.all_subnet_cidrs, 0, local.num_azs)
  public_subnet_cidrs   = slice(local.all_subnet_cidrs, local.num_azs, local.num_azs * 2)
  database_subnet_cidrs = slice(local.all_subnet_cidrs, local.num_azs * 2, local.num_azs * 3)

  # Create subnet mappings with AZ and CIDR (one subnet per type per AZ)
  private_subnets = [
    for az_index in range(local.num_azs) : {
      az_index   = az_index
      az         = local.selected_azs[az_index]
      cidr_block = local.private_subnet_cidrs[az_index]
    }
  ]

  public_subnets = [
    for az_index in range(local.num_azs) : {
      az_index   = az_index
      az         = local.selected_azs[az_index]
      cidr_block = local.public_subnet_cidrs[az_index]
    }
  ]

  database_subnets = [
    for az_index in range(local.num_azs) : {
      az_index   = az_index
      az         = local.selected_azs[az_index]
      cidr_block = local.database_subnet_cidrs[az_index]
    }
  ]

  # Calculate IP allocation summary
  total_private_ips  = local.num_azs * 8192
  total_public_ips   = local.num_azs * 256
  total_database_ips = local.num_azs * 256
  total_used_ips     = local.total_private_ips + local.total_public_ips + local.total_database_ips
  reserved_ips       = 65536 - local.total_used_ips

  # VPC endpoints configuration with defaults
  vpc_endpoints = local.vpc_endpoints_spec != null ? local.vpc_endpoints_spec : {
    enable_s3           = true
    enable_dynamodb     = true
    enable_ecr_api      = true
    enable_ecr_dkr      = true
    enable_eks          = false
    enable_ec2          = false
    enable_ssm          = true
    enable_ssm_messages = true
    enable_ec2_messages = true
    enable_kms          = false
    enable_logs         = false
    enable_monitoring   = false
    enable_sts          = false
    enable_lambda       = false
  }

  # Resource naming prefix
  name_prefix = "${var.environment.unique_name}-${var.instance_name}"

  # Common tags
  common_tags = merge(
    var.environment.cloud_tags,
    local.tags_spec,
    {
      Name        = local.name_prefix
      Environment = var.environment.name
    }
  )

  # EKS tags for public subnets (for external load balancers)
  eks_public_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  # EKS tags for private subnets (for internal load balancers)
  eks_private_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}
