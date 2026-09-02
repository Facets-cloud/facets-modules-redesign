locals {
  output_attributes = {
    gcp_ha_vpn_gateway_name  = google_compute_ha_vpn_gateway.this.name
    gcp_router_name          = google_compute_router.this.name
    gcp_router_asn           = var.instance.spec.gcp_router_asn
    aws_vpn_gateway_id       = local.vgw_id
    aws_vpn_gateway_asn      = var.instance.spec.aws_vgw_asn
    aws_customer_gateway_ids = aws_customer_gateway.gcp[*].id
    aws_vpn_connection_ids   = aws_vpn_connection.this[*].id
    gcp_vpn_tunnel_names     = [for tunnel in google_compute_vpn_tunnel.this : tunnel.name]
    aws_route_table_ids      = distinct([for table in data.aws_route_table.db : table.route_table_id])
    aws_cidrs                = var.instance.spec.aws_cidrs
    gcp_cidr                 = var.instance.spec.gcp_cidr
    mtu                      = var.instance.spec.mtu
  }

  output_interfaces = {}
}
