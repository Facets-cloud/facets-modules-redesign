locals {
  output_attributes = {
    vpc_id          = tostring(vultr_vpc.main.id)
    vpc_description = vultr_vpc.main.description
    region          = local.region
    ip_block        = vultr_vpc.main.v4_subnet
    prefix_length   = tostring(vultr_vpc.main.v4_subnet_mask)
    subnet_cidr     = "${vultr_vpc.main.v4_subnet}/${vultr_vpc.main.v4_subnet_mask}"
  }
  output_interfaces = {
  }
}
