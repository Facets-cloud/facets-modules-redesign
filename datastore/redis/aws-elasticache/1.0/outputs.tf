locals {
  output_attributes = {}
  output_interfaces = {
    cluster = {
      endpoint          = "${local.primary_endpoint}:${local.redis_port}"
      connection_string = var.instance.spec.imports.cluster_id != null && var.instance.spec.imports.cluster_id != "" ? "redis://:YOUR_AUTH_TOKEN@${local.primary_endpoint}:${local.redis_port}" : "redis://:${local.auth_token}@${local.primary_endpoint}:${local.redis_port}"
      auth_token        = local.auth_token
      port              = local.redis_port
    }
    secrets = ["cluster"]
  }
}