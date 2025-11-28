#########################################################################
# Local Values and Calculations                                         #
#########################################################################

locals {
  # Fixed subnet allocation: 1 public + 1 private subnet per AZ
  # Public subnets: /24 (256 IPs each) - smaller allocation
  # Private subnets: /19 (8,192 IPs each) - balanced allocation for /16 network

  # Calculate total subnets needed
  num_azs               = length(var.instance.spec.availability_zones)
  total_public_subnets  = local.num_azs
  total_private_subnets = local.num_azs

  # For /16 CIDR, we'll use:
  # - Public subnets: /24 (256 IPs each)
  # - Private subnets: /19 (8,192 IPs each)

  # Calculate newbits for cidrsubnets function
  vnet_prefix_length     = 16 # We enforce /16 input
  public_subnet_newbits  = 8  # /16 + 8 = /24 (256 IPs)
  private_subnet_newbits = 3  # /16 + 3 = /19 (8,192 IPs) - reduced from /18

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

  # Database subnet configuration - three separate flags
  database_config                   = var.instance.spec.database_config
  enable_general_database_subnet    = local.database_config.enable_general_database_subnet
  enable_postgresql_flexible_subnet = local.database_config.enable_postgresql_flexible_subnet
  enable_mysql_flexible_subnet      = local.database_config.enable_mysql_flexible_subnet

  # Calculate database subnet CIDRs using cidrsubnets function
  # Using /24 for each database subnet type (256 IPs each)
  # These will be allocated after the public and private subnets to avoid conflicts
  database_subnet_newbits = 8 # /16 + 8 = /24 (256 IPs)

  # CRITICAL: Always allocate space for all 3 database subnet types
  # This ensures each subnet type gets a fixed CIDR that never changes
  # even if some subnets are enabled/disabled later
  max_database_subnets = 3 # General, PostgreSQL, MySQL

  # Generate ALL subnet CIDRs including reserved space for database subnets
  # This prevents CIDR reassignment when database subnets are enabled/disabled
  all_subnet_cidrs_with_database = cidrsubnets(
    var.instance.spec.vnet_cidr,
    concat(
      # Public subnets (using /24)
      [for i in range(local.total_public_subnets) : local.public_subnet_newbits],
      # Private subnets (using /18)
      [for i in range(local.total_private_subnets) : local.private_subnet_newbits],
      # ALWAYS reserve space for all 3 database subnets (using /24)
      # Position 0: General, Position 1: PostgreSQL, Position 2: MySQL
      [for i in range(local.max_database_subnets) : local.database_subnet_newbits]
    )...
  )

  # Extract subnet CIDRs by type - updated to use the new allocation
  public_subnet_cidrs  = slice(local.all_subnet_cidrs_with_database, 0, local.total_public_subnets)
  private_subnet_cidrs = slice(local.all_subnet_cidrs_with_database, local.total_public_subnets, local.total_public_subnets + local.total_private_subnets)

  # Extract the database subnet CIDRs with FIXED positions
  # The database CIDRs start after public and private subnets
  database_cidrs_start_index = local.total_public_subnets + local.total_private_subnets

  # Fixed position mapping - these positions NEVER change
  # This ensures subnet CIDRs remain stable when enabling/disabling subnets
  database_subnet_fixed_positions = {
    general    = 0 # Always uses first database subnet position
    postgresql = 1 # Always uses second database subnet position
    mysql      = 2 # Always uses third database subnet position
  }

  # Final database subnet CIDRs - using fixed positions
  # Each subnet type always gets the same CIDR, whether enabled or not
  # The CIDR is allocated but only used when the subnet is enabled
  database_subnet_cidrs = {
    general = local.all_subnet_cidrs_with_database[
      local.database_cidrs_start_index + local.database_subnet_fixed_positions.general
    ]
    postgresql = local.all_subnet_cidrs_with_database[
      local.database_cidrs_start_index + local.database_subnet_fixed_positions.postgresql
    ]
    mysql = local.all_subnet_cidrs_with_database[
      local.database_cidrs_start_index + local.database_subnet_fixed_positions.mysql
    ]
  }

  # DNS Zone configuration - automatically created when subnets are enabled
  create_postgresql_dns_zone = local.enable_postgresql_flexible_subnet
  create_mysql_dns_zone      = local.enable_mysql_flexible_subnet

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
