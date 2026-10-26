locals {
  output_attributes = {
    vpc_id                          = var.instance.spec.vpc_id
    vpc_cidr_block                  = var.instance.spec.vpc_cidr_block
    availability_zones              = var.instance.spec.availability_zones
    private_subnet_ids              = var.instance.spec.private_subnet_ids
    public_subnet_ids               = var.instance.spec.public_subnet_ids
    database_subnet_ids             = var.instance.spec.database_subnet_ids
    database_subnet_group_name      = var.instance.spec.database_subnet_group_name
    internet_gateway_id             = var.instance.spec.internet_gateway_id
    nat_gateway_ids                 = var.instance.spec.nat_gateway_ids
    vpc_endpoint_dynamodb_id        = var.instance.spec.vpc_endpoint_dynamodb_id
    vpc_endpoint_ecr_api_id         = var.instance.spec.vpc_endpoint_ecr_api_id
    vpc_endpoint_ecr_dkr_id         = var.instance.spec.vpc_endpoint_ecr_dkr_id
    vpc_endpoint_s3_id              = var.instance.spec.vpc_endpoint_s3_id
    vpc_endpoints_security_group_id = var.instance.spec.vpc_endpoints_security_group_id
  }
  output_interfaces = {}
}
