# Name module for consistent resource naming with length limits
module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 63
  resource_name = var.instance_name
  resource_type = "alb"
}
