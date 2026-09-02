terraform {
  required_version = ">= 1.5.0"
}

locals {
  gcp_project_id = var.instance.spec.gcp_project_id != "" ? var.instance.spec.gcp_project_id : var.inputs.gcp_cloud_account.attributes.project_id
  gcp_region     = var.instance.spec.gcp_region != "" ? var.instance.spec.gcp_region : var.inputs.gcp_cloud_account.attributes.region

  raw_name   = var.instance.spec.name_prefix != "" ? var.instance.spec.name_prefix : "${var.environment.unique_name}-${var.instance_name}"
  vpn_name   = substr(replace(lower(local.raw_name), "/[^a-z0-9-]/", "-"), 0, 40)
  labels     = { for k, v in var.environment.cloud_tags : replace(lower(k), "/[^a-z0-9_-]/", "_") => replace(lower(v), "/[^a-z0-9_-]/", "_") }
  aws_tags   = merge(var.environment.cloud_tags, { Name = local.vpn_name, ManagedBy = "facets" })
  create_vgw = var.instance.spec.existing_vgw_id == ""
  vgw_id     = local.create_vgw ? aws_vpn_gateway.this[0].id : var.instance.spec.existing_vgw_id

  aws_tunnels = {
    "0" = {
      connection_index   = 0
      tunnel_number      = 1
      gcp_gateway_if     = 0
      peer_gateway_if    = 0
      peer_ip            = aws_vpn_connection.this[0].tunnel1_address
      shared_secret      = aws_vpn_connection.this[0].tunnel1_preshared_key
      cgw_inside_address = aws_vpn_connection.this[0].tunnel1_cgw_inside_address
      vgw_inside_address = aws_vpn_connection.this[0].tunnel1_vgw_inside_address
    }
    "1" = {
      connection_index   = 0
      tunnel_number      = 2
      gcp_gateway_if     = 0
      peer_gateway_if    = 1
      peer_ip            = aws_vpn_connection.this[0].tunnel2_address
      shared_secret      = aws_vpn_connection.this[0].tunnel2_preshared_key
      cgw_inside_address = aws_vpn_connection.this[0].tunnel2_cgw_inside_address
      vgw_inside_address = aws_vpn_connection.this[0].tunnel2_vgw_inside_address
    }
    "2" = {
      connection_index   = 1
      tunnel_number      = 1
      gcp_gateway_if     = 1
      peer_gateway_if    = 2
      peer_ip            = aws_vpn_connection.this[1].tunnel1_address
      shared_secret      = aws_vpn_connection.this[1].tunnel1_preshared_key
      cgw_inside_address = aws_vpn_connection.this[1].tunnel1_cgw_inside_address
      vgw_inside_address = aws_vpn_connection.this[1].tunnel1_vgw_inside_address
    }
    "3" = {
      connection_index   = 1
      tunnel_number      = 2
      gcp_gateway_if     = 1
      peer_gateway_if    = 3
      peer_ip            = aws_vpn_connection.this[1].tunnel2_address
      shared_secret      = aws_vpn_connection.this[1].tunnel2_preshared_key
      cgw_inside_address = aws_vpn_connection.this[1].tunnel2_cgw_inside_address
      vgw_inside_address = aws_vpn_connection.this[1].tunnel2_vgw_inside_address
    }
  }
}

data "aws_route_table" "db" {
  for_each  = toset(var.instance.spec.db_subnet_ids)
  subnet_id = each.value
}

resource "google_compute_ha_vpn_gateway" "this" {
  name    = "${local.vpn_name}-ha-vpn"
  project = local.gcp_project_id
  region  = local.gcp_region
  network = var.instance.spec.gcp_vpc_self_link
}

resource "aws_customer_gateway" "gcp" {
  count = 2

  bgp_asn    = var.instance.spec.gcp_router_asn
  ip_address = google_compute_ha_vpn_gateway.this.vpn_interfaces[count.index].ip_address
  type       = "ipsec.1"

  tags = merge(local.aws_tags, {
    Name = "${local.vpn_name}-gcp-cgw-${count.index}"
  })
}

resource "aws_vpn_gateway" "this" {
  count = local.create_vgw ? 1 : 0

  amazon_side_asn = var.instance.spec.aws_vgw_asn

  tags = merge(local.aws_tags, {
    Name = "${local.vpn_name}-vgw"
  })
}

resource "aws_vpn_gateway_attachment" "this" {
  count = local.create_vgw ? 1 : 0

  vpc_id         = var.instance.spec.aws_vpc_id
  vpn_gateway_id = aws_vpn_gateway.this[0].id
}

resource "aws_vpn_connection" "this" {
  count = 2

  customer_gateway_id = aws_customer_gateway.gcp[count.index].id
  vpn_gateway_id      = local.vgw_id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_ike_versions = ["ikev2"]
  tunnel2_ike_versions = ["ikev2"]

  tags = merge(local.aws_tags, {
    Name = "${local.vpn_name}-conn-${count.index}"
  })

  depends_on = [aws_vpn_gateway_attachment.this]
}

resource "google_compute_external_vpn_gateway" "aws" {
  name            = "${local.vpn_name}-aws-ext"
  project         = local.gcp_project_id
  redundancy_type = "FOUR_IPS_REDUNDANCY"
  description     = "AWS VPN tunnel outside addresses for ${local.vpn_name}"

  interface {
    id         = 0
    ip_address = aws_vpn_connection.this[0].tunnel1_address
  }

  interface {
    id         = 1
    ip_address = aws_vpn_connection.this[0].tunnel2_address
  }

  interface {
    id         = 2
    ip_address = aws_vpn_connection.this[1].tunnel1_address
  }

  interface {
    id         = 3
    ip_address = aws_vpn_connection.this[1].tunnel2_address
  }
}

resource "google_compute_router" "this" {
  name    = "${local.vpn_name}-router"
  project = local.gcp_project_id
  region  = local.gcp_region
  network = var.instance.spec.gcp_vpc_self_link

  bgp {
    asn            = var.instance.spec.gcp_router_asn
    advertise_mode = "CUSTOM"

    advertised_ip_ranges {
      range = var.instance.spec.gcp_cidr
    }
  }
}

resource "google_compute_vpn_tunnel" "this" {
  for_each = local.aws_tunnels

  name                            = "${local.vpn_name}-tun-${each.key}"
  project                         = local.gcp_project_id
  region                          = local.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.this.id
  vpn_gateway_interface           = each.value.gcp_gateway_if
  peer_external_gateway           = google_compute_external_vpn_gateway.aws.id
  peer_external_gateway_interface = each.value.peer_gateway_if
  shared_secret                   = each.value.shared_secret
  router                          = google_compute_router.this.id
  ike_version                     = 2
}

resource "google_compute_router_interface" "this" {
  for_each = local.aws_tunnels

  name       = "${local.vpn_name}-if-${each.key}"
  project    = local.gcp_project_id
  region     = local.gcp_region
  router     = google_compute_router.this.name
  ip_range   = "${each.value.cgw_inside_address}/30"
  vpn_tunnel = google_compute_vpn_tunnel.this[each.key].name
}

resource "google_compute_router_peer" "this" {
  for_each = local.aws_tunnels

  name                      = "${local.vpn_name}-peer-${each.key}"
  project                   = local.gcp_project_id
  region                    = local.gcp_region
  router                    = google_compute_router.this.name
  interface                 = google_compute_router_interface.this[each.key].name
  peer_ip_address           = each.value.vgw_inside_address
  peer_asn                  = var.instance.spec.aws_vgw_asn
  advertised_route_priority = 100
}

resource "aws_vpn_gateway_route_propagation" "rds" {
  for_each = toset([for table in data.aws_route_table.db : table.route_table_id])

  route_table_id = each.key
  vpn_gateway_id = local.vgw_id

  depends_on = [aws_vpn_connection.this]
}

resource "google_compute_firewall" "allow_aws_to_db" {
  name          = "${local.vpn_name}-aws-db"
  project       = local.gcp_project_id
  network       = var.instance.spec.gcp_vpc_self_link
  direction     = "INGRESS"
  source_ranges = var.instance.spec.aws_cidrs
  description   = "Allow AWS VPC CIDRs to reach database ports and ICMP over HA VPN."

  allow {
    protocol = "tcp"
    ports    = [for port in var.instance.spec.allowed_tcp_ports : tostring(port)]
  }

  allow {
    protocol = "icmp"
  }
}
