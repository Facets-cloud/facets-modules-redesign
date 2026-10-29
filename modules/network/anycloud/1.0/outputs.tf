# Output contract: @facets/any_cloud_network
# common → attributes; cloud-specific → interfaces.aws / .gcp

locals {
  # Common, cloud-agnostic contract every consumer relies on (cluster, ingress, mysql, postgres,
  # redis, nfs, batch, ec2, compute_engine). Exactly one branch is active; count/for_each-gated
  # resources on the inactive side splat to [] / null, so concat/one resolve to the real values.
  output_attributes = {
    cloud_provider      = local.cloud_provider
    network_id          = local.is_aws ? one(aws_vpc.main[*].id) : one(google_compute_network.this[*].id)
    vpc_id              = local.is_aws ? one(aws_vpc.main[*].id) : one(google_compute_network.this[*].id)
    cidr                = local.cidr
    region              = local.is_aws ? local.aws_region : local.gcp_region
    project_id          = local.gcp_project
    private_subnet_ids  = concat(values(aws_subnet.private)[*].id, google_compute_subnetwork.private[*].id)
    public_subnet_ids   = concat(values(aws_subnet.public)[*].id, google_compute_subnetwork.public[*].id)
    database_subnet_ids = concat(values(aws_subnet.database)[*].id, google_compute_subnetwork.database[*].id)
  }

  output_interfaces = {
    # AWS VPC specifics — populated when AWS, else null-keyed (empty {} loses type across modules)
    aws = local.is_aws ? {
      availability_zones         = local.aws_selected_azs
      internet_gateway_id        = one(aws_internet_gateway.main[*].id)
      nat_gateway_ids            = values(aws_nat_gateway.main)[*].id
      database_subnet_group_name = one(aws_db_subnet_group.database[*].name)
      vpc_endpoint_s3_id         = one(aws_vpc_endpoint.s3[*].id)
      vpc_endpoint_dynamodb_id   = one(aws_vpc_endpoint.dynamodb[*].id)
      vpc_endpoint_ids           = { for k, e in aws_vpc_endpoint.interface : k => e.id }
      vpc_endpoints_sg_id        = one(aws_security_group.vpc_endpoints[*].id)
      } : {
      availability_zones         = []
      internet_gateway_id        = null
      nat_gateway_ids            = []
      database_subnet_group_name = null
      vpc_endpoint_s3_id         = null
      vpc_endpoint_dynamodb_id   = null
      vpc_endpoint_ids           = {}
      vpc_endpoints_sg_id        = null
    }

    # GCP VPC specifics — populated when GCP, else null-keyed
    gcp = local.is_gcp ? {
      zones                               = local.gcp_selected_zones
      vpc_self_link                       = one(google_compute_network.this[*].self_link)
      vpc_name                            = one(google_compute_network.this[*].name)
      gke_pods_range_name                 = "${local.name_prefix}-gke-pods"
      gke_pods_cidr                       = local.gcp_gke_pods_subnet_cidr
      gke_services_range_name             = "${local.name_prefix}-gke-services"
      gke_services_cidr                   = local.gcp_gke_services_subnet_cidr
      private_subnet_name                 = one(google_compute_subnetwork.private[*].name)
      internal_lb_subnet_id               = one(google_compute_subnetwork.internal_lb[*].id)
      router_id                           = one(google_compute_router.router[*].id)
      router_name                         = one(google_compute_router.router[*].name)
      nat_name                            = one(google_compute_router_nat.nat[*].name)
      nat_gateway_ids                     = google_compute_router_nat.nat[*].id
      network_tags                        = local.gcp_network_tags
      vpc_connector_enabled               = local.vpc_connector_enabled
      vpc_connector_id                    = one(google_vpc_access_connector.connector[*].id)
      vpc_connector_name                  = one(google_vpc_access_connector.connector[*].name)
      vpc_connector_self_link             = one(google_vpc_access_connector.connector[*].self_link)
      private_services_connection_id      = one(google_service_networking_connection.google_services[*].id)
      private_services_peering_connection = one(google_service_networking_connection.google_services[*].peering)
      private_services_range_name         = one(google_compute_global_address.google_services[*].name)
      private_services_range_address      = one(google_compute_global_address.google_services[*].address)
      google_services_cidr                = local.gcp_google_services_cidr
      } : {
      zones                               = []
      vpc_self_link                       = null
      vpc_name                            = null
      gke_pods_range_name                 = null
      gke_pods_cidr                       = null
      gke_services_range_name             = null
      gke_services_cidr                   = null
      private_subnet_name                 = null
      internal_lb_subnet_id               = null
      router_id                           = null
      router_name                         = null
      nat_name                            = null
      nat_gateway_ids                     = []
      network_tags                        = {}
      vpc_connector_enabled               = false
      vpc_connector_id                    = null
      vpc_connector_name                  = null
      vpc_connector_self_link             = null
      private_services_connection_id      = null
      private_services_peering_connection = null
      private_services_range_name         = null
      private_services_range_address      = null
      google_services_cidr                = null
    }
  }
}

