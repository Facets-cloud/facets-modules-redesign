locals {
  output_attributes = {
    vpc_id                          = aws_vpc.main.id
    vpc_cidr_block                  = aws_vpc.main.cidr_block
    nat_gateway_ids                 = [aws_nat_gateway.main.id]
    public_subnet_ids               = [for k, s in aws_subnet.public : s.id]
    private_subnet_ids              = [for k, s in aws_subnet.private : s.id]
    database_subnet_ids             = []
    database_subnet_group_name      = null
    internet_gateway_id             = aws_internet_gateway.main.id
    availability_zones              = distinct(concat([for s in aws_subnet.public : s.availability_zone], [for s in aws_subnet.private : s.availability_zone]))
    vpc_endpoint_s3_id              = try([for k, e in aws_vpc_endpoint.gateway : e.id][0], null)
    vpc_endpoint_dynamodb_id        = null
    vpc_endpoint_ecr_api_id         = null
    vpc_endpoint_ecr_dkr_id         = null
    vpc_endpoints_security_group_id = null
  }
  output_interfaces = {
  }
}
