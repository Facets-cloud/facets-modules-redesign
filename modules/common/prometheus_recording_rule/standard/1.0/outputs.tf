locals {
  output_attributes = {}
  output_interfaces = {}
}

output "record-group-output" {
  value = {
    "record-group-output" = local.userspecified_rules
  }
}