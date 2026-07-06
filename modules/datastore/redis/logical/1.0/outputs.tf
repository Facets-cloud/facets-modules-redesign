locals {
  output_attributes = {}

  # Pure passthrough of the source Redis datastore's @facets/redis interface,
  # with db_index reflected into the connection_string. No resources are created.
  output_interfaces = {
    cluster = {
      endpoint          = local.source_endpoint
      connection_string = local.connection_string
      auth_token        = local.source_auth_token
      port              = local.source_port
      secrets           = local.source_secrets
    }
  }
}
