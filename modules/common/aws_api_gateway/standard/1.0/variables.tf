variable "instance" {
  description = "AWS API Gateway module configuration"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      ########################################
      # API Gateway
      ########################################
      protocol                     = optional(string, "HTTP")
      description                  = optional(string, "API Gateway provisioned by Facets")
      api_version                  = optional(string)
      body                         = optional(string)
      credentials_arn              = optional(string)
      disable_execute_api_endpoint = optional(bool, false)
      fail_on_warnings             = optional(bool, false)
      ip_address_type              = optional(string)
      route_key                    = optional(string)
      route_selection_expression   = optional(string)
      api_key_selection_expression = optional(string)
      target                       = optional(string)
      api_mapping_key              = optional(string)

      ########################################
      # Domain Name
      ########################################
      domain_name                                        = optional(string, "")
      domain_name_certificate_arn                        = optional(string)
      domain_name_ownership_verification_certificate_arn = optional(string)
      create_domain_name                                 = optional(bool, true)
      hosted_zone_name                                   = optional(string)
      private_zone                                       = optional(bool, false)

      ########################################
      # Domain - Route53 Records
      ########################################
      create_domain_records  = optional(bool, true)
      subdomains             = optional(list(string), [])
      subdomain_record_types = optional(list(string), ["A", "AAAA"])

      ########################################
      # Domain - Certificate
      ########################################
      create_certificate = optional(bool, true)

      ########################################
      # Mutual TLS
      ########################################
      mutual_tls_authentication = optional(object({
        truststore_uri     = optional(string)
        truststore_version = optional(string)
      }), {})

      ########################################
      # CORS
      ########################################
      cors_configuration = optional(object({
        allow_credentials = optional(bool)
        allow_headers     = optional(list(string))
        allow_methods     = optional(list(string))
        allow_origins     = optional(list(string))
        expose_headers    = optional(list(string), [])
        max_age           = optional(number)
      }))

      ########################################
      # Stage
      ########################################
      create_stage               = optional(bool, true)
      deploy_stage               = optional(bool, true)
      stage_name                 = optional(string, "$default")
      stage_description          = optional(string)
      stage_client_certificate_id = optional(string)
      stage_variables            = optional(map(string), {})
      stage_tags                 = optional(map(string), {})

      stage_access_log_settings = optional(object({
        create_log_group            = optional(bool, true)
        destination_arn             = optional(string)
        format                      = optional(string)
        log_group_name              = optional(string)
        log_group_retention_in_days = optional(number, 30)
        log_group_kms_key_id        = optional(string)
        log_group_skip_destroy      = optional(bool)
        log_group_class             = optional(string)
        log_group_tags              = optional(map(string), {})
      }), {})

      stage_default_route_settings = optional(object({
        data_trace_enabled       = optional(bool, true)
        detailed_metrics_enabled = optional(bool, true)
        logging_level            = optional(string)
        throttling_burst_limit   = optional(number, 500)
        throttling_rate_limit    = optional(number, 1000)
      }), {})

      ########################################
      # Authorizers
      ########################################
      authorizers = optional(map(object({
        authorizer_credentials_arn        = optional(string)
        authorizer_payload_format_version = optional(string)
        authorizer_result_ttl_in_seconds  = optional(number)
        authorizer_type                   = optional(string, "REQUEST")
        authorizer_uri                    = optional(string)
        enable_simple_responses           = optional(bool)
        identity_sources                  = optional(list(string))
        jwt_configuration = optional(object({
          audience = optional(list(string))
          issuer   = optional(string)
        }))
        name = optional(string)
      })), {})

      ########################################
      # Routes & Integrations
      ########################################
      create_routes_and_integrations = optional(bool, true)

      routes = optional(map(object({
        # Route
        authorizer_key             = optional(string)
        api_key_required           = optional(bool)
        authorization_scopes       = optional(list(string), [])
        authorization_type         = optional(string)
        authorizer_id              = optional(string)
        model_selection_expression = optional(string)
        operation_name             = optional(string)
        request_models             = optional(map(string), {})
        request_parameter = optional(object({
          request_parameter_key = optional(string)
          required              = optional(bool, false)
        }), {})
        route_response_selection_expression = optional(string)

        # Per-route settings
        data_trace_enabled       = optional(bool)
        detailed_metrics_enabled = optional(bool)
        logging_level            = optional(string)
        throttling_burst_limit   = optional(number)
        throttling_rate_limit    = optional(number)

        # Route response
        route_response = optional(object({
          create                     = optional(bool, false)
          model_selection_expression = optional(string)
          response_models            = optional(map(string))
          route_response_key         = optional(string, "$default")
        }), {})

        # Integration
        integration = object({
          connection_id             = optional(string)
          vpc_link_key              = optional(string)
          connection_type           = optional(string)
          content_handling_strategy = optional(string)
          credentials_arn           = optional(string)
          description               = optional(string)
          method                    = optional(string)
          subtype                   = optional(string)
          type                      = optional(string, "AWS_PROXY")
          uri                       = optional(string)
          passthrough_behavior      = optional(string)
          payload_format_version    = optional(string)
          request_parameters        = optional(map(string), {})
          request_templates         = optional(map(string), {})
          response_parameters = optional(list(object({
            mappings    = map(string)
            status_code = string
          })))
          template_selection_expression = optional(string)
          timeout_milliseconds          = optional(number)
          tls_config = optional(object({
            server_name_to_verify = optional(string)
          }))
          response = optional(object({
            content_handling_strategy     = optional(string)
            integration_response_key      = optional(string)
            response_templates            = optional(map(string))
            template_selection_expression = optional(string)
          }), {})
        })
      })), {})

      ########################################
      # VPC Links
      ########################################
      vpc_link_security_group_ids = optional(list(string), [])
      vpc_link_tags               = optional(map(string), {})
    })
  })
}

variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    cloud_account = object({
      attributes = object({
        aws_iam_role = string
        session_name = string
        external_id  = string
        aws_region   = string
      })
      interfaces = optional(object({}), {})
    })
    network_details = object({
      attributes = object({
        vpc_id             = string
        public_subnet_ids  = list(string)
        private_subnet_ids = optional(list(string), [])
        vpc_cidr_block     = optional(string)
      })
      interfaces = optional(object({}), {})
    })
  })
}
