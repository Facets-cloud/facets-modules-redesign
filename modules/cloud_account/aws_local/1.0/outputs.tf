locals {
  output_interfaces = {}
  output_attributes = {
    aws_region = var.instance.spec.region
  }
}
