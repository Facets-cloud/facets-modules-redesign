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

  # Adopted (imported) VPC endpoints — keyed by a stable semantic name so any number of endpoints
  # (incl. two of the same service) can be adopted; the live vpce- ids live only in the import blocks.
  adopt_endpoints           = lookup(local.spec, "endpoints", [])
  adopt_endpoints_interface = { for e in local.adopt_endpoints : e.key => e if lookup(e, "type", "") == "Interface" }
  adopt_endpoints_gateway   = { for e in local.adopt_endpoints : e.key => e if lookup(e, "type", "") == "Gateway" }

  # Import config (optional - for importing existing VPCs)
  import_config = lookup(local.spec, "import_config", null)

  # Database subnets toggle
  enable_database_subnets = lookup(local.spec, "enable_database_subnets", true)

  # Determine which availability zones to use
  selected_azs = local.auto_select_azs ? (
    length(data.aws_availability_zones.available.names) >= 3 ?
    slice(data.aws_availability_zones.available.names, 0, 3) :
    slice(data.aws_availability_zones.available.names, 0, min(length(data.aws_availability_zones.available.names), 3))
  ) : local.availability_zones

  # Validate AZ count (2-5 AZs supported)
  num_azs           = length(local.selected_azs)
  validate_az_count = local.num_azs >= 2 && local.num_azs <= 5 ? true : tobool("Number of AZs must be between 2 and 5 for /16 VPC")

  # Custom subnets support for import
  custom_private_subnets = lookup(local.spec, "custom_private_subnets", null)
  custom_public_subnets  = lookup(local.spec, "custom_public_subnets", null)

  # Subnet prefix configuration (overridable for import)
  private_subnet_prefix  = lookup(local.spec, "private_subnet_prefix", 19)
  public_subnet_prefix   = lookup(local.spec, "public_subnet_prefix", 24)
  database_subnet_prefix = lookup(local.spec, "database_subnet_prefix", 24)

  # Fixed subnet allocation for K8s-optimized VPC
  vpc_prefix = 16

  # Calculate newbits for cidrsubnets function
  private_newbits  = local.private_subnet_prefix - local.vpc_prefix
  public_newbits   = local.public_subnet_prefix - local.vpc_prefix
  database_newbits = local.database_subnet_prefix - local.vpc_prefix

  # Create ordered list of newbits for cidrsubnets function
  all_subnet_newbits = local.custom_private_subnets != null ? [] : concat(
    [for i in range(local.num_azs) : local.private_newbits],
    [for i in range(local.num_azs) : local.public_newbits],
    local.enable_database_subnets ? [for i in range(local.num_azs) : local.database_newbits] : []
  )

  # Generate all subnet CIDRs using cidrsubnets function - prevents overlaps
  all_subnet_cidrs = length(local.all_subnet_newbits) > 0 ? cidrsubnets(local.vpc_cidr, local.all_subnet_newbits...) : []

  # Extract subnet CIDRs by type (auto-calculated or custom)
  private_subnet_cidrs = local.custom_private_subnets != null ? [
    for k, v in local.custom_private_subnets : v.cidr_block
  ] : slice(local.all_subnet_cidrs, 0, local.num_azs)

  public_subnet_cidrs = local.custom_public_subnets != null ? [
    for k, v in local.custom_public_subnets : v.cidr_block
  ] : slice(local.all_subnet_cidrs, local.num_azs, local.num_azs * 2)

  database_subnet_cidrs = local.enable_database_subnets && local.custom_private_subnets == null ? (
    slice(local.all_subnet_cidrs, local.num_azs * 2, local.num_azs * 3)
  ) : []

  # Create subnet mappings with unique key, AZ, and CIDR
  private_subnets = local.custom_private_subnets != null ? [
    for k, v in local.custom_private_subnets : {
      key        = k
      az_index   = index(keys(local.custom_private_subnets), k)
      az         = v.az
      cidr_block = v.cidr_block
    }
    ] : [
    for az_index in range(local.num_azs) : {
      key        = local.selected_azs[az_index]
      az_index   = az_index
      az         = local.selected_azs[az_index]
      cidr_block = local.private_subnet_cidrs[az_index]
    }
  ]

  public_subnets = local.custom_public_subnets != null ? [
    for k, v in local.custom_public_subnets : {
      key        = k
      az_index   = index(keys(local.custom_public_subnets), k)
      az         = v.az
      cidr_block = v.cidr_block
    }
    ] : [
    for az_index in range(local.num_azs) : {
      key        = local.selected_azs[az_index]
      az_index   = az_index
      az         = local.selected_azs[az_index]
      cidr_block = local.public_subnet_cidrs[az_index]
    }
  ]

  database_subnets = local.enable_database_subnets && local.custom_private_subnets == null ? [
    for az_index in range(local.num_azs) : {
      az_index   = az_index
      az         = local.selected_azs[az_index]
      cidr_block = local.database_subnet_cidrs[az_index]
    }
  ] : []

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
