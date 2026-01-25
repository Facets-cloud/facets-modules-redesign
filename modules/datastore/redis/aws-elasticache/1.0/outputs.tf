locals {
  output_attributes = {}
  output_interfaces = {
    cluster = {
      endpoint          = "${local.primary_endpoint}:${local.redis_port}"
      connection_string = "redis://:${local.auth_token}@${local.primary_endpoint}:${local.redis_port}"
      auth_token        = local.auth_token
      port              = local.redis_port
      secrets           = ["auth_token", "connection_string"]
    }
  }
}