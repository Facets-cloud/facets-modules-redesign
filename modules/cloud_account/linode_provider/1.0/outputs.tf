locals {
  output_attributes = {
    token   = var.instance.spec.token
    region  = var.instance.spec.region
    secrets = "[\"token\"]"
  }
  output_interfaces = {
  }
}
