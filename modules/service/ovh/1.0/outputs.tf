locals {
  output_attributes = {
    selector_labels = module.app-helm-chart.selector_labels
    namespace       = module.app-helm-chart.namespace
    resource_type   = local.resource_type
    resource_name   = local.resource_name
    service_name    = var.instance_name
  }
  output_interfaces = {
    default = {
      host     = "${var.instance_name}.${local.namespace}.svc.cluster.local"
      username = "\"\""
      password = "\"\""
      port     = "8080"
      name     = var.instance_name
      secrets  = "[\"password\"]"
    }
  }
}