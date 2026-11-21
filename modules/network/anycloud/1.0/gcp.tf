# GCP branch — GKE-optimized VPC network. All resources count-gated on the linked account
# resolving to GCP. Subnets/secondary ranges auto-calculated in locals.tf.

data "google_compute_zones" "available" {
  count  = local.is_gcp ? 1 : 0
  region = local.gcp_region
  status = "UP"
}

resource "google_compute_network" "this" {
  count                   = local.is_gcp ? 1 : 0
  name                    = local.name_prefix
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  description             = "VPC network created by Facets for ${var.environment.name}"
}

# Private subnet (general workloads + GKE nodes) with GKE pod/service secondary ranges
resource "google_compute_subnetwork" "private" {
  count                    = local.is_gcp ? 1 : 0
  name                     = "${local.name_prefix}-private"
  ip_cidr_range            = local.gcp_private_subnet_cidr
  region                   = local.gcp_region
  network                  = google_compute_network.this[0].id
  private_ip_google_access = true
  description              = "Private subnet for general workloads and GKE nodes"

  secondary_ip_range {
    range_name    = "${local.name_prefix}-gke-pods"
    ip_cidr_range = local.gcp_gke_pods_subnet_cidr
  }
  secondary_ip_range {
    range_name    = "${local.name_prefix}-gke-services"
    ip_cidr_range = local.gcp_gke_services_subnet_cidr
  }

  dynamic "log_config" {
    for_each = local.gcp_enable_flow_logs ? [1] : []
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

resource "google_compute_subnetwork" "public" {
  count                    = local.is_gcp ? 1 : 0
  name                     = "${local.name_prefix}-public"
  ip_cidr_range            = local.gcp_public_subnet_cidr
  region                   = local.gcp_region
  network                  = google_compute_network.this[0].id
  private_ip_google_access = false
  description              = "Public subnet for NAT and public-facing resources"

  dynamic "log_config" {
    for_each = local.gcp_enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

resource "google_compute_subnetwork" "database" {
  count                    = local.is_gcp ? 1 : 0
  name                     = "${local.name_prefix}-database"
  ip_cidr_range            = local.gcp_database_subnet_cidr
  region                   = local.gcp_region
  network                  = google_compute_network.this[0].id
  private_ip_google_access = true
  description              = "Database subnet for Cloud SQL and managed databases"

  dynamic "log_config" {
    for_each = local.gcp_enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# Proxy-only subnet for GKE internal HTTP(S) load balancers
resource "google_compute_subnetwork" "internal_lb" {
  count         = local.is_gcp ? 1 : 0
  name          = "${local.name_prefix}-internal-lb"
  ip_cidr_range = local.gcp_internal_lb_subnet_cidr
  region        = local.gcp_region
  network       = google_compute_network.this[0].id
  purpose       = "INTERNAL_HTTPS_LOAD_BALANCER"
  role          = "ACTIVE"
  description   = "Proxy-only subnet for GKE internal load balancers"
}

# Google-services private peering (Cloud SQL / Memorystore / etc.)
resource "google_compute_global_address" "google_services" {
  count         = local.is_gcp ? 1 : 0
  name          = "${local.name_prefix}-google-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = local.gcp_google_services_prefix
  address       = cidrhost(local.gcp_google_services_cidr, 0)
  network       = google_compute_network.this[0].id
  description   = "IP range for Google managed services"
  labels        = local.common_labels
}

resource "google_service_networking_connection" "google_services" {
  count                   = local.is_gcp ? 1 : 0
  network                 = google_compute_network.this[0].id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.google_services[0].name]
}

# Cloud Router + NAT (egress for private nodes)
resource "google_compute_router" "router" {
  count       = local.is_gcp ? 1 : 0
  name        = "${local.name_prefix}-router"
  region      = local.gcp_region
  network     = google_compute_network.this[0].id
  description = "Router for Cloud NAT"

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "nat" {
  count                              = local.is_gcp ? 1 : 0
  name                               = "${local.name_prefix}-nat"
  router                             = google_compute_router.router[0].name
  region                             = google_compute_router.router[0].region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Serverless VPC Access Connector (optional)
resource "google_vpc_access_connector" "connector" {
  count         = local.is_gcp && local.vpc_connector_enabled ? 1 : 0
  name          = "${local.name_prefix}-connector"
  region        = local.gcp_region
  ip_cidr_range = local.gcp_vpc_connector_subnet_cidr
  network       = google_compute_network.this[0].name
  machine_type  = local.vpc_connector_machine_type
  min_instances = local.vpc_connector_min_instances
  max_instances = local.vpc_connector_max_instances
}

# ───────── Firewall rules ─────────
resource "google_compute_firewall" "allow_internal" {
  count       = local.is_gcp && local.gcp_firewall_rules.allow_internal ? 1 : 0
  name        = "${local.name_prefix}-allow-internal"
  network     = google_compute_network.this[0].name
  description = "Allow internal traffic between all subnets"

  allow { protocol = "icmp" }
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [local.cidr]
  priority      = 1000
}

resource "google_compute_firewall" "allow_ssh" {
  count       = local.is_gcp && local.gcp_firewall_rules.allow_ssh ? 1 : 0
  name        = "${local.name_prefix}-allow-ssh"
  network     = google_compute_network.this[0].name
  description = "Allow SSH from internet to instances with the ssh-access tag"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [local.gcp_network_tags.ssh_access]
  priority      = 1000
}

resource "google_compute_firewall" "allow_http" {
  count       = local.is_gcp && local.gcp_firewall_rules.allow_http ? 1 : 0
  name        = "${local.name_prefix}-allow-http"
  network     = google_compute_network.this[0].name
  description = "Allow HTTP from internet to instances with the http-server tag"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [local.gcp_network_tags.http_server]
  priority      = 1000
}

resource "google_compute_firewall" "allow_https" {
  count       = local.is_gcp && local.gcp_firewall_rules.allow_https ? 1 : 0
  name        = "${local.name_prefix}-allow-https"
  network     = google_compute_network.this[0].name
  description = "Allow HTTPS from internet to instances with the https-server tag"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = [local.gcp_network_tags.https_server]
  priority      = 1000
}

resource "google_compute_firewall" "allow_icmp" {
  count       = local.is_gcp && local.gcp_firewall_rules.allow_icmp ? 1 : 0
  name        = "${local.name_prefix}-allow-icmp"
  network     = google_compute_network.this[0].name
  description = "Allow ICMP (ping) within the VPC"

  allow { protocol = "icmp" }
  source_ranges = [local.cidr]
  priority      = 1000
}
