locals {
  output_attributes = {
    api_key = var.instance.spec.api_key
    region  = var.instance.spec.region
    secrets = "[\"api_key\"]"
  }
  output_interfaces = {
  }
}
