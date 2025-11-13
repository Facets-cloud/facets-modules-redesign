locals {
  output_attributes = {
    uid            = random_string.uid.result
    configmap_name = lower(var.instance_name)
    namespace      = local.namespace
  }
  output_interfaces = {}
}

output "uid" {
  value       = random_string.uid.result
  description = "The random string generated for dashboard"
}

output "attributes" {
  value       = local.output_attributes
  description = "Grafana Dashboard attributes"
}

output "interfaces" {
  value       = local.output_interfaces
  description = "Grafana Dashboard interfaces"
}
