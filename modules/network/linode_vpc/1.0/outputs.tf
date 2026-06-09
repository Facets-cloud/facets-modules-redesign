locals {
  output_attributes = {
    vpc_id       = tostring(linode_vpc.main.id)
    vpc_label    = linode_vpc.main.label
    region       = local.region
    subnet_id    = tostring(linode_vpc_subnet.main.id)
    subnet_label = linode_vpc_subnet.main.label
    subnet_cidr  = linode_vpc_subnet.main.ipv4
  }
  output_interfaces = {
  }
}
