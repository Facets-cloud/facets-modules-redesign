locals {
  output_attributes = {
    # VPC Core
    vpc_id        = google_compute_network.vpc.id
    vpc_name      = google_compute_network.vpc.name
    vpc_self_link = google_compute_network.vpc.self_link
    region        = local.gcp_region
    project_id    = local.gcp_project

    # Subnets - Regional resources in GCP
    private_subnet_id   = google_compute_subnetwork.private.id
    private_subnet_name = google_compute_subnetwork.private.name
    private_subnet_cidr = google_compute_subnetwork.private.ip_cidr_range

    public_subnet_id   = google_compute_subnetwork.public.id
    public_subnet_name = google_compute_subnetwork.public.name
    public_subnet_cidr = google_compute_subnetwork.public.ip_cidr_range

    database_subnet_id   = google_compute_subnetwork.database.id
    database_subnet_name = google_compute_subnetwork.database.name
    database_subnet_cidr = google_compute_subnetwork.database.ip_cidr_range

    # GKE-specific (always available)
    internal_lb_subnet_id   = google_compute_subnetwork.internal_lb.id
    internal_lb_subnet_name = google_compute_subnetwork.internal_lb.name
    internal_lb_subnet_cidr = google_compute_subnetwork.internal_lb.ip_cidr_range

    # GKE secondary ranges (always available)
    gke_pods_range_name     = "${local.name_prefix}-gke-pods"
    gke_pods_cidr           = local.gke_pods_subnet_cidr
    gke_services_range_name = "${local.name_prefix}-gke-services"
    gke_services_cidr       = local.gke_services_subnet_cidr

    # NAT and Router
    router_id   = google_compute_router.router.id
    router_name = google_compute_router.router.name
    nat_id      = google_compute_router_nat.nat.id
    nat_name    = google_compute_router_nat.nat.name

    # Google Services Peering
    google_services_network = google_service_networking_connection.google_services.network
    google_services_cidr    = "${google_compute_global_address.google_services.address}/${google_compute_global_address.google_services.prefix_length}"

    # Firewall Rules - compact list of enabled rules only
    firewall_rule_ids = compact([
      lookup(local.firewall_rules, "allow_internal", true) ? google_compute_firewall.allow_internal[0].id : "",
      lookup(local.firewall_rules, "allow_ssh", true) ? google_compute_firewall.allow_ssh[0].id : "",
      lookup(local.firewall_rules, "allow_http", false) ? google_compute_firewall.allow_http[0].id : "",
      lookup(local.firewall_rules, "allow_https", true) ? google_compute_firewall.allow_https[0].id : "",
      lookup(local.firewall_rules, "allow_icmp", true) ? google_compute_firewall.allow_icmp[0].id : ""
    ])

    # Network Tags (for use by other resources)
    network_tags = local.network_tags

    # Summary information
    total_private_ips     = local.total_private_ips
    total_public_ips      = local.total_public_ips
    total_database_ips    = local.total_database_ips
    total_gke_pod_ips     = local.total_gke_pods
    total_gke_service_ips = local.total_gke_services
    reserved_ips          = local.reserved_ips
  }

  output_interfaces = {
    # Empty for now - can be extended if needed
  }
}