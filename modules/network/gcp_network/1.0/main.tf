module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 32
  resource_name   = var.instance_name
  resource_type   = "network"
  globally_unique = true
  prefix          = "vpc-"
}

# Data source to get compute zones in the region
data "google_compute_zones" "available" {
  region = var.inputs.cloud_account.attributes.region
  status = "UP"
}

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = local.name_prefix
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "VPC network created by Facets for ${var.environment.name}"

  # Note: project is inherited from provider
}

# Private Subnet (for general workloads and GKE nodes)
resource "google_compute_subnetwork" "private" {
  name                     = "${local.name_prefix}-private"
  ip_cidr_range            = local.private_subnet_cidr
  region                   = local.gcp_region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
  description              = "Private subnet for general workloads and GKE nodes"

  # GKE secondary ranges (always enabled for GKE readiness)
  secondary_ip_range {
    range_name    = "${local.name_prefix}-gke-pods"
    ip_cidr_range = local.gke_pods_subnet_cidr
  }

  secondary_ip_range {
    range_name    = "${local.name_prefix}-gke-services"
    ip_cidr_range = local.gke_services_subnet_cidr
  }

  dynamic "log_config" {
    for_each = local.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }

  lifecycle {
    ignore_changes = [secondary_ip_range]
  }
}

# Public Subnet (for resources that need public IPs)
resource "google_compute_subnetwork" "public" {
  name                     = "${local.name_prefix}-public"
  ip_cidr_range            = local.public_subnet_cidr
  region                   = local.gcp_region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = false
  description              = "Public subnet for NAT and public-facing resources"

  dynamic "log_config" {
    for_each = local.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# Database Subnet (for Cloud SQL and managed databases)
resource "google_compute_subnetwork" "database" {
  name                     = "${local.name_prefix}-database"
  ip_cidr_range            = local.database_subnet_cidr
  region                   = local.gcp_region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
  description              = "Database subnet for Cloud SQL and managed databases"

  dynamic "log_config" {
    for_each = local.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# Internal Load Balancer Subnet (for GKE internal LBs) - Always enabled for GKE readiness
resource "google_compute_subnetwork" "internal_lb" {
  name          = "${local.name_prefix}-internal-lb"
  ip_cidr_range = local.internal_lb_subnet_cidr
  region        = local.gcp_region
  network       = google_compute_network.vpc.id
  purpose       = "INTERNAL_HTTPS_LOAD_BALANCER"
  role          = "ACTIVE"
  description   = "Proxy-only subnet for GKE internal load balancers"
}

# Google Services VPC Peering (for Cloud SQL, Memorystore, etc.) - CRITICAL
resource "google_compute_global_address" "google_services" {
  name          = "${local.name_prefix}-google-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = local.google_services_prefix
  address       = cidrhost(local.google_services_subnet_cidr, 0)
  network       = google_compute_network.vpc.id
  description   = "IP range for Google managed services"

  # Facets labels
  labels = local.common_labels
}

resource "google_service_networking_connection" "google_services" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.google_services.name]
}

# Cloud Router for NAT
resource "google_compute_router" "router" {
  name        = "${local.name_prefix}-router"
  region      = local.gcp_region
  network     = google_compute_network.vpc.id
  description = "Router for Cloud NAT"

  bgp {
    asn = 64514
  }
}

# Cloud NAT
resource "google_compute_router_nat" "nat" {
  name                               = "${local.name_prefix}-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
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

  name        = "${local.name_prefix}-allow-internal"
  network     = google_compute_network.vpc.name
  description = "Allow internal traffic between all subnets"

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

  source_ranges = [local.vpc_cidr]
  priority      = 1000
}

# Allow SSH from internet to instances with ssh-access tag
resource "google_compute_firewall" "allow_ssh" {
  count = lookup(local.firewall_rules, "allow_ssh", true) ? 1 : 0

  name        = "${local.name_prefix}-allow-ssh"
  network     = google_compute_network.vpc.name
  description = "Allow SSH from internet to instances with ssh-access tag"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [local.network_tags.ssh_access]
  priority      = 1000
}

# Allow HTTP from internet to instances with http-server tag
resource "google_compute_firewall" "allow_http" {
  count = lookup(local.firewall_rules, "allow_http", false) ? 1 : 0

  name        = "${local.name_prefix}-allow-http"
  network     = google_compute_network.vpc.name
  description = "Allow HTTP from internet to instances with http-server tag"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [local.network_tags.http_server]
  priority      = 1000
}

# Allow HTTPS from internet to instances with https-server tag
resource "google_compute_firewall" "allow_https" {
  count = lookup(local.firewall_rules, "allow_https", true) ? 1 : 0

  name        = "${local.name_prefix}-allow-https"
  network     = google_compute_network.vpc.name
  description = "Allow HTTPS from internet to instances with https-server tag"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [local.network_tags.https_server]
  priority      = 1000
}

# Allow ICMP (ping) within VPC
resource "google_compute_firewall" "allow_icmp" {
  count = lookup(local.firewall_rules, "allow_icmp", true) ? 1 : 0

  name        = "${local.name_prefix}-allow-icmp"
  network     = google_compute_network.vpc.name
  description = "Allow ICMP (ping) within VPC"

  allow {
    protocol = "icmp"
  }

  source_ranges = [local.vpc_cidr]
  priority      = 1000
}
