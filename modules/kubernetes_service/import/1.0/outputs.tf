locals {
  output_attributes = { resource_name = join(",", sort(keys(local.items))) }
  output_interfaces = {}
}
