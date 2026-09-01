# The @facets/aws-vpc-details contract: exactly 12 attributes, no interfaces.
# Emitted identically in every posture - this is what lets a brownfield VPC be a
# drop-in swap for a greenfield one. Every AWS consumer reads only three of them
# (vpc_id, vpc_cidr_block, private_subnet_ids), but the contract is the contract.
locals {
  output_attributes = {
    vpc_id              = aws_vpc.this.id
    vpc_cidr_block      = aws_vpc.this.cidr_block
    availability_zones  = local.plan_azs
    internet_gateway_id = aws_internet_gateway.this.id

    public_subnet_ids   = [for k in local.public_subnet_keys : aws_subnet.this[k].id]
    private_subnet_ids  = [for k in local.private_subnet_keys : aws_subnet.this[k].id]
    database_subnet_ids = [for k in local.database_subnet_keys : aws_subnet.this[k].id]

    nat_gateway_ids = [for k, n in local.nat_gateways : aws_nat_gateway.this[k].id]

    # Keyed by plan key, so a peering or transit module can name a table the same
    # way this module does - route_tables: [main, pvt-2a] - instead of pasting rtb- ids.
    route_table_ids = { for k, rt in local.route_tables : k => aws_route_table.this[k].id }

    # Keyed the same way, for consumers that need a specific SUBSET of subnets rather
    # than a whole tier - an EKS cluster placed in 8 of 11, a node group in exactly one.
    subnet_ids = { for k, s in local.subnets : k => aws_subnet.this[k].id }

    vpc_endpoint_s3_id       = try(aws_vpc_endpoint.gateway["s3"].id, null)
    vpc_endpoint_dynamodb_id = try(aws_vpc_endpoint.gateway["dynamodb"].id, null)
    vpc_endpoint_ecr_api_id  = try(aws_vpc_endpoint.interface["ecr_api"].id, null)
    vpc_endpoint_ecr_dkr_id  = try(aws_vpc_endpoint.interface["ecr_dkr"].id, null)

    vpc_endpoints_security_group_id = try(aws_security_group.vpc_endpoints[0].id, null)

    # Not part of the declared output type; kept for 1.0 parity with consumers
    # that read it off the raw attribute map.
    database_subnet_group_name = try(aws_db_subnet_group.database[0].name, null)
  }

  output_interfaces = {}
}
