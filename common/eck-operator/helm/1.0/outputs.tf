locals {
  output_attributes = {
    namespace       = local.namespace
    release_name    = helm_release.eck_operator.name
    chart_version   = helm_release.eck_operator.version
    operator_name   = "elastic-operator"
    repository      = local.repository
    chart_name      = local.chart_name
    webhook_enabled = true
    status          = helm_release.eck_operator.status
    revision        = helm_release.eck_operator.metadata[0].revision
  }

  output_interfaces = {
    operator = {
      namespace       = local.namespace
      release_name    = var.instance_name
      operator_name   = "elastic-operator"
      webhook_service = "elastic-webhook-server"
      webhook_port    = 9443
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