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

  # Database subnet configuration
  database_config         = var.instance.spec.database_config
  enable_database_subnets = local.database_config.enable_database_subnets

  # Calculate database subnet CIDRs
  # If user provides specific CIDRs, use them; otherwise, auto-calculate
  # Using /24 for each database subnet type (256 IPs each)
  # Start from x.x.100.0/24 for databases to avoid conflict with other subnets
  vnet_base = split(".", split("/", var.instance.spec.vnet_cidr)[0])

  # Default database subnet CIDRs if not provided
  default_database_cidrs = {
    general    = "${local.vnet_base[0]}.${local.vnet_base[1]}.100.0/24"
    postgresql = "${local.vnet_base[0]}.${local.vnet_base[1]}.101.0/24"
    mysql      = "${local.vnet_base[0]}.${local.vnet_base[1]}.102.0/24"
  }

  # Final database subnet CIDRs
  database_subnet_cidrs = {
    general    = lookup(local.database_config.database_subnet_cidrs, "general", local.default_database_cidrs.general)
    postgresql = lookup(local.database_config.database_subnet_cidrs, "postgresql", local.default_database_cidrs.postgresql)
    mysql      = lookup(local.database_config.database_subnet_cidrs, "mysql", local.default_database_cidrs.mysql)
  }

  # DNS Zone configuration
  create_postgresql_dns_zone = local.enable_database_subnets && lookup(local.database_config.create_dns_zones, "postgresql", true)
  create_mysql_dns_zone      = local.enable_database_subnets && lookup(local.database_config.create_dns_zones, "mysql", true)

  # DNS Zone names - using environment unique name for uniqueness
  postgresql_dns_zone_name = "pg-${var.environment.unique_name}.postgres.database.azure.com"
  mysql_dns_zone_name      = "mysql-${var.environment.unique_name}.mysql.database.azure.com"

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
