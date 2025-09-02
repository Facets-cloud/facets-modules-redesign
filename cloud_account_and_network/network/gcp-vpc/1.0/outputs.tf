locals {
  output_attributes = {
    zones                 = local.selected_zones
    region                = var.instance.spec.region
    vpc_id                = google_compute_network.main.id
    vpc_name              = google_compute_network.main.name
    project_id            = var.inputs.cloud_account.attributes.project
    router_ids            = values(google_compute_router.main)[*].id
    vpc_self_link         = google_compute_network.main.self_link
    nat_gateway_ids       = values(google_compute_router_nat.main)[*].id
    firewall_rule_ids     = compact(concat(try([google_compute_firewall.allow_internal[0].id], []), try([google_compute_firewall.allow_ssh[0].id], []), try([google_compute_firewall.allow_http[0].id], []), try([google_compute_firewall.allow_https[0].id], []), try([google_compute_firewall.allow_icmp[0].id], [])))
    public_subnet_ids     = values(google_compute_subnetwork.public)[*].id
    private_subnet_ids    = values(google_compute_subnetwork.private)[*].id
    database_subnet_ids   = values(google_compute_subnetwork.database)[*].id
    public_subnet_cidrs   = [for subnet in local.public_subnets : subnet.cidr_block]
    private_subnet_cidrs  = [for subnet in local.private_subnets : subnet.cidr_block]
    database_subnet_cidrs = [for subnet in local.database_subnets : subnet.cidr_block]
  }
  output_interfaces = {
  }
}