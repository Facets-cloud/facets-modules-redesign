# Data source to get available zones in the region
data "google_compute_zones" "available" {
  region = var.instance.spec.region
  status = "UP"
}

# Local values for calculations
locals {
  # Determine which zones to use - ensure we have enough zones for auto selection
  selected_zones = lookup(var.instance.spec, "auto_select_zones", false) ? (
    length(data.google_compute_zones.available.names) >= 3 ?
    slice(data.google_compute_zones.available.names, 0, 3) :
    data.google_compute_zones.available.names
  ) : lookup(var.instance.spec, "zones", [])

  # Calculate subnet mask from IP count
  subnet_mask_map = {
    "256"  = 24 # /24 = 256 IPs
    "512"  = 23 # /23 = 512 IPs  
    "1024" = 22 # /22 = 1024 IPs
    "2048" = 21 # /21 = 2048 IPs
    "4096" = 20 # /20 = 4096 IPs
    "8192" = 19 # /19 = 8192 IPs
  }

  vpc_prefix_length = tonumber(split("/", var.instance.spec.vpc_cidr)[1])

  public_subnet_newbits   = local.subnet_mask_map[var.instance.spec.public_subnets.subnet_size] - local.vpc_prefix_length
  private_subnet_newbits  = local.subnet_mask_map[var.instance.spec.private_subnets.subnet_size] - local.vpc_prefix_length
  database_subnet_newbits = local.subnet_mask_map[var.instance.spec.database_subnets.subnet_size] - local.vpc_prefix_length

  # Calculate total number of subnets needed
  public_total_subnets   = length(local.selected_zones) * var.instance.spec.public_subnets.count_per_zone
  private_total_subnets  = length(local.selected_zones) * var.instance.spec.private_subnets.count_per_zone
  database_total_subnets = length(local.selected_zones) * var.instance.spec.database_subnets.count_per_zone

  # Create list of newbits for cidrsubnets function
  # Order: public subnets, private subnets, database subnets
  subnet_newbits = concat(
    var.instance.spec.public_subnets.count_per_zone > 0 ? [
      for i in range(local.public_total_subnets) : local.public_subnet_newbits
    ] : [],
    [for i in range(local.private_total_subnets) : local.private_subnet_newbits],
    [for i in range(local.database_total_subnets) : local.database_subnet_newbits]
  )

  # Generate all subnet CIDRs using cidrsubnets function - this prevents overlaps
  all_subnet_cidrs = cidrsubnets(var.instance.spec.vpc_cidr, local.subnet_newbits...)

  # Extract subnet CIDRs by type
  public_subnet_cidrs = var.instance.spec.public_subnets.count_per_zone > 0 ? slice(
    local.all_subnet_cidrs,
    0,
    local.public_total_subnets
  ) : []

  private_subnet_cidrs = slice(
    local.all_subnet_cidrs,
    var.instance.spec.public_subnets.count_per_zone > 0 ? local.public_total_subnets : 0,
    var.instance.spec.public_subnets.count_per_zone > 0 ? local.public_total_subnets + local.private_total_subnets : local.private_total_subnets
  )

  database_subnet_cidrs = slice(
    local.all_subnet_cidrs,
    var.instance.spec.public_subnets.count_per_zone > 0 ? local.public_total_subnets + local.private_total_subnets : local.private_total_subnets,
    var.instance.spec.public_subnets.count_per_zone > 0 ? local.public_total_subnets + local.private_total_subnets + local.database_total_subnets : local.private_total_subnets + local.database_total_subnets
  )

  # Create subnet mappings with zone and CIDR
  public_subnets = var.instance.spec.public_subnets.count_per_zone > 0 ? flatten([
    for zone_index, zone in local.selected_zones : [
      for subnet_index in range(var.instance.spec.public_subnets.count_per_zone) : {
        zone_index   = zone_index
        subnet_index = subnet_index
        zone         = zone
        cidr_block   = local.public_subnet_cidrs[zone_index * var.instance.spec.public_subnets.count_per_zone + subnet_index]
      }
    ]
  ]) : []

  private_subnets = flatten([
    for zone_index, zone in local.selected_zones : [
      for subnet_index in range(var.instance.spec.private_subnets.count_per_zone) : {
        zone_index   = zone_index
        subnet_index = subnet_index
        zone         = zone
        cidr_block   = local.private_subnet_cidrs[zone_index * var.instance.spec.private_subnets.count_per_zone + subnet_index]
      }
    ]
  ])

  database_subnets = flatten([
    for zone_index, zone in local.selected_zones : [
      for subnet_index in range(var.instance.spec.database_subnets.count_per_zone) : {
        zone_index   = zone_index
        subnet_index = subnet_index
        zone         = zone
        cidr_block   = local.database_subnet_cidrs[zone_index * var.instance.spec.database_subnets.count_per_zone + subnet_index]
      }
    ]
  ])

  # Firewall rules configuration with defaults
  firewall_rules = var.instance.spec.firewall_rules != null ? var.instance.spec.firewall_rules : {
    allow_internal = true
    allow_ssh      = true
    allow_http     = true
    allow_https    = true
    allow_icmp     = true
  }

  # Private Google Access configuration with defaults
  private_google_access = var.instance.spec.private_google_access != null ? var.instance.spec.private_google_access : {
    enable_private_subnets  = true
    enable_database_subnets = true
  }

  # Resource naming prefix - ensure GCP naming compliance
  # GCP resource names must be 63 chars or less, lowercase, start with letter, no underscores
  raw_name_prefix = "${var.environment.unique_name}-${var.instance_name}"
  # Replace underscores with hyphens and ensure lowercase
  clean_name_prefix = lower(replace(local.raw_name_prefix, "_", "-"))
  # Truncate more aggressively to ensure room for longest suffix (keep first 25 chars)
  # Longest suffix is "-database-us-central1-c-1" which is 23 chars, so 25+23+15 = 63 chars max
  name_prefix = length(local.clean_name_prefix) > 25 ? substr(local.clean_name_prefix, 0, 25) : local.clean_name_prefix

  # Common labels
  common_labels = merge(
    var.environment.cloud_tags,
    lookup(var.instance.spec, "tags", {}),
    {
      name        = local.name_prefix
      environment = var.environment.name
    }
  )
}

# VPC Network
resource "google_compute_network" "main" {
  name                    = "${local.name_prefix}-vpc"
  auto_create_subnetworks = false
  mtu                     = 1460
  routing_mode            = "REGIONAL"

  lifecycle {
    prevent_destroy = true
  }
}

# Public Subnets
resource "google_compute_subnetwork" "public" {
  for_each = var.instance.spec.public_subnets.count_per_zone > 0 ? {
    for subnet in local.public_subnets :
    "${subnet.zone}-${subnet.subnet_index}" => subnet
  } : {}

  name                     = "${local.name_prefix}-public-${each.value.zone}-${each.value.subnet_index + 1}"
  ip_cidr_range            = each.value.cidr_block
  region                   = var.instance.spec.region
  network                  = google_compute_network.main.id
  private_ip_google_access = false
}

# Private Subnets
resource "google_compute_subnetwork" "private" {
  for_each = {
    for subnet in local.private_subnets :
    "${subnet.zone}-${subnet.subnet_index}" => subnet
  }

  name                     = "${local.name_prefix}-private-${each.value.zone}-${each.value.subnet_index + 1}"
  ip_cidr_range            = each.value.cidr_block
  region                   = var.instance.spec.region
  network                  = google_compute_network.main.id
  private_ip_google_access = lookup(local.private_google_access, "enable_private_subnets", true)
}

# Database Subnets
resource "google_compute_subnetwork" "database" {
  for_each = {
    for subnet in local.database_subnets :
    "${subnet.zone}-${subnet.subnet_index}" => subnet
  }

  name                     = "${local.name_prefix}-database-${each.value.zone}-${each.value.subnet_index + 1}"
  ip_cidr_range            = each.value.cidr_block
  region                   = var.instance.spec.region
  network                  = google_compute_network.main.id
  private_ip_google_access = lookup(local.private_google_access, "enable_database_subnets", true)
}

# Cloud Router for NAT Gateway
resource "google_compute_router" "main" {
  for_each = var.instance.spec.nat_gateway.strategy == "per_zone" ? {
    for zone in local.selected_zones : zone => zone
    } : var.instance.spec.public_subnets.count_per_zone > 0 ? {
    single = local.selected_zones[0]
  } : {}

  name    = var.instance.spec.nat_gateway.strategy == "per_zone" ? "${local.name_prefix}-router-${each.key}" : "${local.name_prefix}-router"
  region  = var.instance.spec.region
  network = google_compute_network.main.id
}

# Cloud NAT Gateway
resource "google_compute_router_nat" "main" {
  for_each = var.instance.spec.nat_gateway.strategy == "per_zone" ? {
    for zone in local.selected_zones : zone => zone
    } : var.instance.spec.public_subnets.count_per_zone > 0 ? {
    single = local.selected_zones[0]
  } : {}

  name   = var.instance.spec.nat_gateway.strategy == "per_zone" ? "${local.name_prefix}-nat-${each.key}" : "${local.name_prefix}-nat"
  router = google_compute_router.main[each.key].name
  region = var.instance.spec.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall Rules
# Allow internal traffic within VPC
resource "google_compute_firewall" "allow_internal" {
  count = lookup(local.firewall_rules, "allow_internal", true) ? 1 : 0

  name    = "${local.name_prefix}-allow-internal"
  network = google_compute_network.main.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [var.instance.spec.vpc_cidr]
  priority      = 1000
}

# Allow SSH access from internet
resource "google_compute_firewall" "allow_ssh" {
  count = lookup(local.firewall_rules, "allow_ssh", true) ? 1 : 0

  name    = "${local.name_prefix}-allow-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-access"]
  priority      = 1000
}

# Allow HTTP access from internet
resource "google_compute_firewall" "allow_http" {
  count = lookup(local.firewall_rules, "allow_http", true) ? 1 : 0

  name    = "${local.name_prefix}-allow-http"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
  priority      = 1000
}

# Allow HTTPS access from internet
resource "google_compute_firewall" "allow_https" {
  count = lookup(local.firewall_rules, "allow_https", true) ? 1 : 0

  name    = "${local.name_prefix}-allow-https"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["https-server"]
  priority      = 1000
}

# Allow ICMP
resource "google_compute_firewall" "allow_icmp" {
  count = lookup(local.firewall_rules, "allow_icmp", true) ? 1 : 0

  name    = "${local.name_prefix}-allow-icmp"
  network = google_compute_network.main.name

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  priority      = 1000
}