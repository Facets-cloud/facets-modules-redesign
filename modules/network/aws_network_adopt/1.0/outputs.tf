locals {
  output_attributes = {
    vpc_id                          = data.aws_vpc.this.id
    vpc_cidr_block                  = data.aws_vpc.this.cidr_block
    nat_gateway_ids                 = data.aws_nat_gateways.this.ids
    public_subnet_ids               = local.public_ids
    private_subnet_ids              = local.private_ids
    database_subnet_ids             = local.database_ids
    database_subnet_group_name      = null
    internet_gateway_id             = data.aws_internet_gateway.this.id
    availability_zones              = distinct([for s in data.aws_subnet.this : s.availability_zone])
    vpc_endpoint_s3_id              = null
    vpc_endpoint_dynamodb_id        = null
    vpc_endpoint_ecr_api_id         = null
    vpc_endpoint_ecr_dkr_id         = null
    vpc_endpoints_security_group_id = null
  }
  output_interfaces = {
  }
}
