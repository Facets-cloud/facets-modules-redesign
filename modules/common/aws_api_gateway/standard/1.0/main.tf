module "apigateway-name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = false
  globally_unique = true
  resource_name   = lower(var.instance_name)
  resource_type   = "aws_apigateway"
  limit           = 50
  environment     = var.environment
}

module "api_gateway" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "6.1.0"

  ########################################
  # API Gateway
  ########################################
  name                         = module.apigateway-name.name
  description                  = lookup(local.spec, "description", "API Gateway provisioned by Facets")
  protocol_type                = lookup(local.spec, "protocol", "HTTP")
  body                         = lookup(local.spec, "body", null)
  credentials_arn              = lookup(local.spec, "credentials_arn", null)
  disable_execute_api_endpoint = lookup(local.spec, "disable_execute_api_endpoint", false)
  fail_on_warnings             = lookup(local.spec, "fail_on_warnings", false)
  ip_address_type              = lookup(local.spec, "ip_address_type", null)
  route_key                    = lookup(local.spec, "route_key", null)
  route_selection_expression   = lookup(local.spec, "route_selection_expression", null)
  api_key_selection_expression = lookup(local.spec, "api_key_selection_expression", null)
  target                       = lookup(local.spec, "target", null)
  api_version                  = lookup(local.spec, "api_version", null)
  api_mapping_key              = lookup(local.spec, "api_mapping_key", null)
  tags                         = var.environment.cloud_tags

  ########################################
  # CORS & Mutual TLS
  ########################################
  cors_configuration        = local.cors_configuration
  mutual_tls_authentication = local.mutual_tls_authentication

  ########################################
  # Domain Name
  ########################################
  domain_name                                        = lookup(local.spec, "domain_name", "")
  domain_name_certificate_arn                        = lookup(local.spec, "domain_name_certificate_arn", null)
  domain_name_ownership_verification_certificate_arn = lookup(local.spec, "domain_name_ownership_verification_certificate_arn", null)
  create_domain_name                                 = lookup(local.spec, "create_domain_name", true)
  hosted_zone_name                                   = lookup(local.spec, "hosted_zone_name", null)
  private_zone                                       = lookup(local.spec, "private_zone", false)

  ########################################
  # Domain - Route53 Records & Certificate
  ########################################
  create_domain_records  = lookup(local.spec, "create_domain_records", true)
  subdomains             = lookup(local.spec, "subdomains", [])
  subdomain_record_types = lookup(local.spec, "subdomain_record_types", ["A", "AAAA"])
  create_certificate     = lookup(local.spec, "create_certificate", true)

  ########################################
  # Authorizers
  ########################################
  authorizers = local.authorizers

  ########################################
  # Stage
  ########################################
  create_stage                = lookup(local.spec, "create_stage", true)
  deploy_stage                = lookup(local.spec, "deploy_stage", true)
  stage_name                  = lookup(local.spec, "stage_name", "$default")
  stage_description           = lookup(local.spec, "stage_description", null)
  stage_client_certificate_id = lookup(local.spec, "stage_client_certificate_id", null)
  stage_variables             = lookup(local.spec, "stage_variables", {})
  stage_tags                  = lookup(local.spec, "stage_tags", {})
  stage_access_log_settings   = local.stage_access_log_settings
  stage_default_route_settings = local.stage_default_route_settings

  ########################################
  # VPC Links
  ########################################
  vpc_links = {
    "${module.apigateway-name.name}-vpc" = {
      security_group_ids = lookup(local.spec, "vpc_link_security_group_ids", [])
      subnet_ids         = var.inputs.network_details.attributes.public_subnet_ids
    }
  }
  vpc_link_tags = local.vpc_link_tags

  ########################################
  # Routes & Integrations
  ########################################
  create_routes_and_integrations = lookup(local.spec, "create_routes_and_integrations", true)
  routes                         = local.routes
}
