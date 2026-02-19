locals {
  spec = lookup(var.instance, "spec", {})

  # CORS — null when not set (upstream default is null)
  cors_configuration = lookup(local.spec, "cors_configuration", null)

  # Mutual TLS
  mutual_tls_authentication = lookup(local.spec, "mutual_tls_authentication", {})

  # Stage access log settings
  stage_access_log_settings = lookup(local.spec, "stage_access_log_settings", {})

  # Stage default route settings
  stage_default_route_settings = lookup(local.spec, "stage_default_route_settings", {})

  # Authorizers
  authorizers = lookup(local.spec, "authorizers", {})

  # VPC link tags
  vpc_link_tags = lookup(local.spec, "vpc_link_tags", {})

  # Build v6.1.0 routes map — each route has a nested `integration` object
  routes = {
    for route_key, route_val in lookup(local.spec, "routes", {}) :
    route_key => {
      # Route
      authorizer_key             = lookup(route_val, "authorizer_key", null)
      api_key_required           = lookup(route_val, "api_key_required", null)
      authorization_scopes       = lookup(route_val, "authorization_scopes", [])
      authorization_type         = lookup(route_val, "authorization_type", null)
      authorizer_id              = lookup(route_val, "authorizer_id", null)
      model_selection_expression = lookup(route_val, "model_selection_expression", null)
      operation_name             = lookup(route_val, "operation_name", null)
      request_models             = lookup(route_val, "request_models", {})
      request_parameter          = lookup(route_val, "request_parameter", {})
      route_response_selection_expression = lookup(route_val, "route_response_selection_expression", null)

      # Per-route settings
      data_trace_enabled       = lookup(route_val, "data_trace_enabled", null)
      detailed_metrics_enabled = lookup(route_val, "detailed_metrics_enabled", null)
      logging_level            = lookup(route_val, "logging_level", null)
      throttling_burst_limit   = lookup(route_val, "throttling_burst_limit", null)
      throttling_rate_limit    = lookup(route_val, "throttling_rate_limit", null)

      # Route response
      route_response = lookup(route_val, "route_response", {})

      # Integration
      integration = {
        connection_id             = lookup(lookup(route_val, "integration", {}), "connection_id", null)
        vpc_link_key              = lookup(lookup(route_val, "integration", {}), "vpc_link_key", null)
        connection_type           = lookup(lookup(route_val, "integration", {}), "connection_type", null)
        content_handling_strategy = lookup(lookup(route_val, "integration", {}), "content_handling_strategy", null)
        credentials_arn           = lookup(lookup(route_val, "integration", {}), "credentials_arn", null)
        description               = lookup(lookup(route_val, "integration", {}), "description", null)
        method                    = lookup(lookup(route_val, "integration", {}), "method", null)
        subtype                   = lookup(lookup(route_val, "integration", {}), "subtype", null)
        type                      = lookup(lookup(route_val, "integration", {}), "type", "AWS_PROXY")
        uri                       = lookup(lookup(route_val, "integration", {}), "uri", null)
        passthrough_behavior      = lookup(lookup(route_val, "integration", {}), "passthrough_behavior", null)
        payload_format_version    = lookup(lookup(route_val, "integration", {}), "payload_format_version", null)
        request_parameters        = lookup(lookup(route_val, "integration", {}), "request_parameters", {})
        request_templates         = lookup(lookup(route_val, "integration", {}), "request_templates", {})
        response_parameters       = lookup(lookup(route_val, "integration", {}), "response_parameters", null)
        template_selection_expression = lookup(lookup(route_val, "integration", {}), "template_selection_expression", null)
        timeout_milliseconds      = lookup(lookup(route_val, "integration", {}), "timeout_milliseconds", null)
        tls_config                = lookup(lookup(route_val, "integration", {}), "tls_config", null)
        response                  = lookup(lookup(route_val, "integration", {}), "response", {})
      }
    }
  }
}
