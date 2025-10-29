locals {
  release       = lookup(local.spec, "release", {})
  strategy      = lookup(local.release, "strategy", {})
  strategy_type = lookup(local.strategy, "type", null)
  output_interfaces = merge({
    for k, v in lookup(local.runtime, "ports", {}) : k => {
      host      = "${var.instance_name}.${local.namespace}.svc.cluster.local"
      username  = ""
      password  = ""
      port      = lookup(v, "service_port", v.port)
      port_name = k
      name      = var.instance_name
      secrets   = ["password"]
    }
    },
    local.strategy_type == "BlueGreen" || local.strategy_type == "Canary" ?
    { for k, v in lookup(local.runtime, "ports", {}) : "${k}-preview" => {
      host      = "${var.instance_name}-preview.${local.namespace}.svc.cluster.local"
      username  = ""
      password  = ""
      port      = lookup(v, "service_port", v.port)
      port_name = k
      name      = "${var.instance_name}-preview"
      secrets   = ["password"]
      }
    } : {}
  )

  output_attributes = {
    selector_labels = module.app-helm-chart.selector_labels
    namespace       = module.app-helm-chart.namespace
    resource_type   = local.resource_type
    resource_name   = local.resource_name
    service_name    = var.instance_name
  }
}
