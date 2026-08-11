# Pure ADOPT module: reads an existing VPC + subnets read-only.
# Creates NOTHING -> a plan against a live VPC is 0 create / 0 change / 0 destroy.

locals {
  spec         = var.instance.spec
  vpc_id       = local.spec.existing_vpc_id
  public_ids   = tolist(lookup(local.spec, "public_subnet_ids", []))
  private_ids  = tolist(lookup(local.spec, "private_subnet_ids", []))
  database_ids = tolist(lookup(local.spec, "database_subnet_ids", []))
  all_ids      = toset(concat(local.public_ids, local.private_ids, local.database_ids))
}

data "aws_vpc" "this" {
  id = local.vpc_id
}

data "aws_subnet" "this" {
  for_each = local.all_ids
  id       = each.value
}

data "aws_internet_gateway" "this" {
  filter {
    name   = "attachment.vpc-id"
    values = [local.vpc_id]
  }
}

data "aws_nat_gateways" "this" {
  vpc_id = local.vpc_id
}
