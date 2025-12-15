locals {
  output_attributes = {
  }
  output_interfaces = {
    s3_api = {
      endpoint   = local.s3_endpoint
      host       = local.api_host
      port       = local.api_port
      access_key = local.access_key
      secret_key = local.secret_key
      region     = "us-east-1"
    }
    console = {
      url      = local.console_url
      host     = local.console_host
      port     = local.console_port
      username = local.access_key
      password = local.secret_key
    }
  }
}