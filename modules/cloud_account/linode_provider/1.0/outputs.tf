locals {
  output_attributes = {
    token   = sensitive(var.instance.spec.token)
    region  = var.instance.spec.region
    secrets = "[\"token\"]"
  }
  output_interfaces = {
  }
}
