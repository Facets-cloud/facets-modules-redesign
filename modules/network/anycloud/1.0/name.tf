# Resource naming: user-supplied spec.name wins; otherwise fall back to the
# facets name utility module (env-scoped, unique, length-capped auto name).
module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  resource_name = var.instance_name
  resource_type = "network"
  limit         = 63
}

locals {
  name_override = trimspace(try(local.spec.name, ""))
  resource_name = local.name_override != "" ? local.name_override : module.name.name
}
