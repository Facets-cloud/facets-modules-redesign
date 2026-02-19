locals {
  output_attributes = {
    api_id        = module.api_gateway.api_id
    api_arn       = module.api_gateway.api_arn
    api_endpoint  = module.api_gateway.api_endpoint
    invoke_url    = module.api_gateway.stage_invoke_url
    execution_arn = module.api_gateway.api_execution_arn
    stage_id      = module.api_gateway.stage_id
    stage_arn     = module.api_gateway.stage_arn
    protocol_type = lookup(local.spec, "protocol", "HTTP")
    name          = module.apigateway-name.name
  }

  output_interfaces = {}
}
