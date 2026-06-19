# Vultr Load Balancer Module
# Fronts a set of compute instances (from the compute input) with forwarding
# rules, a health check, and optional SSL redirect / proxy protocol.

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 32
  resource_name = var.instance_name
  resource_type = "lb"
}

locals {
  region = coalesce(
    try(var.instance.spec.region, null),
    try(var.inputs.compute.attributes.region, null),
    var.inputs.vultr_cloud_account.attributes.region
  )
  vpc_id = try(var.inputs.network.attributes.vpc_id, null)
}

resource "vultr_load_balancer" "this" {
  region              = local.region
  label               = module.name.name
  balancing_algorithm = var.instance.spec.balancing_algorithm
  ssl_redirect        = var.instance.spec.ssl_redirect
  proxy_protocol      = var.instance.spec.proxy_protocol
  attached_instances  = var.inputs.compute.attributes.instance_ids
  vpc                 = local.vpc_id

  dynamic "forwarding_rules" {
    for_each = var.instance.spec.forwarding_rules
    content {
      frontend_protocol = forwarding_rules.value.frontend_protocol
      frontend_port     = forwarding_rules.value.frontend_port
      backend_protocol  = forwarding_rules.value.backend_protocol
      backend_port      = forwarding_rules.value.backend_port
    }
  }

  health_check {
    protocol            = var.instance.spec.health_check.protocol
    port                = var.instance.spec.health_check.port
    path                = var.instance.spec.health_check.path
    check_interval      = var.instance.spec.health_check.check_interval
    response_timeout    = var.instance.spec.health_check.response_timeout
    unhealthy_threshold = var.instance.spec.health_check.unhealthy_threshold
    healthy_threshold   = var.instance.spec.health_check.healthy_threshold
  }
}
