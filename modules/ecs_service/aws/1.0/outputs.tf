locals {
  output_attributes = {
    resource_type   = "ecs_service"
    resource_name   = var.instance_name
    service_name    = var.instance_name
    ecs_service_arn = module.ecs.id
    cluster_arn     = var.inputs.ecs_details.attributes.cluster_arn
  }

  output_interfaces = {
    for port_name, port_value in lookup(local.runtime, "ports", {}) : port_name => {
      host              = "-"
      port              = tonumber(port_value.port)
      connection_string = "-"
      username          = ""
      password          = ""
    }
  }
}
