locals {
  output_attributes = {
    namespace        = local.namespace
    release_name     = var.instance_name
    chart_version    = local.chart_version
    operator_name    = "elastic-operator"
    repository       = local.repository
    chart_name       = local.chart_name
    webhook_enabled  = true
    managed_namespaces = lookup(local.final_values, "managedNamespaces", ["elastic-system"])
  }
  
  output_interfaces = {
    operator = {
      namespace        = local.namespace
      release_name     = var.instance_name
      operator_name    = "elastic-operator"
      webhook_service  = "elastic-webhook-server"
      webhook_port     = 9443
    }
    webhook = {
      service = "elastic-webhook-server"
      port    = 9443
      path    = "/validate"
    }
  }
}

output "attributes" {
  description = "All attributes of the ECK Operator instance"
  value       = local.output_attributes
}

output "interfaces" {
  description = "Interface endpoints for the ECK Operator"
  value       = local.output_interfaces
}