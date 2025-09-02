#########################################################################
# Local Values and Calculations                                         #
#########################################################################

locals {
  # Fixed subnet allocation: 1 public + 1 private subnet per AZ
  # Public subnets: /24 (256 IPs each) - smaller allocation
  # Private subnets: /18 (16,384 IPs each) - larger allocation as requested

  # Calculate total subnets needed
  num_azs               = length(var.instance.spec.availability_zones)
  total_public_subnets  = local.num_azs
  total_private_subnets = local.num_azs

  # For /16 CIDR, we'll use:
  # - Public subnets: /24 (256 IPs each)
  # - Private subnets: /18 (16,384 IPs each)

  # Calculate newbits for cidrsubnets function
  vnet_prefix_length     = 16 # We enforce /16 input
  public_subnet_newbits  = 8  # /16 + 8 = /24 (256 IPs)
  private_subnet_newbits = 2  # /16 + 2 = /18 (16,384 IPs)

  # Create list of newbits for cidrsubnets function
  # Order: all public subnets first, then all private subnets
  subnet_newbits_list = concat(
    # Public subnets (smaller)
    [for i in range(local.total_public_subnets) : local.public_subnet_newbits],
    # Private subnets (larger)
    [for i in range(local.total_private_subnets) : local.private_subnet_newbits]
  )

  # Generate all subnet CIDRs using cidrsubnets function - this prevents overlaps
  all_subnet_cidrs = cidrsubnets(var.instance.spec.vnet_cidr, local.subnet_newbits_list...)

  # Extract subnet CIDRs by type
  public_subnet_cidrs  = slice(local.all_subnet_cidrs, 0, local.total_public_subnets)
  private_subnet_cidrs = slice(local.all_subnet_cidrs, local.total_public_subnets, local.total_public_subnets + local.total_private_subnets)

  # Create subnet mappings with AZ and CIDR
  # Public subnets - 1 per AZ
  public_subnets = [
    for az_index, az in var.instance.spec.availability_zones : {
      az_index   = az_index
      az         = az
      cidr_block = local.public_subnet_cidrs[az_index]
    }
  ]

  # Private subnets - 1 per AZ
  private_subnets = [
    for az_index, az in var.instance.spec.availability_zones : {
      az_index   = az_index
      az         = az
      cidr_block = local.private_subnet_cidrs[az_index]
    }
  ]

  # Resource naming prefix
  name_prefix = "${var.environment.unique_name}-${var.instance_name}"

  # Common tags
  common_tags = merge(
    var.environment.cloud_tags,
    lookup(var.instance.spec, "tags", {}),
    {
      Name        = local.name_prefix
      Environment = var.environment.name
    }
  )
}
