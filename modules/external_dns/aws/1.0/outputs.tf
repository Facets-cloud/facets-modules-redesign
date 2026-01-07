locals {
  output_attributes = {
    secret_name                = kubernetes_secret.external_dns_r53_secret.metadata[0].name
    secret_namespace           = local.namespace
    aws_access_key_id_key      = "access-key-id"
    aws_secret_access_key_key  = "secret-access-key"
    gcp_credentials_json_key   = ""
    azure_credentials_json_key  = ""
    hosted_zone_id             = local.hosted_zone_id
    region                     = local.aws_region
    provider                   = "aws"
  }
  output_interfaces = {}
}
