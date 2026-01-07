locals {
  output_attributes = {
    secret_name                = kubernetes_secret.external_dns_gcp_secret.metadata[0].name
    secret_namespace           = local.namespace
    aws_access_key_id_key      = ""
    aws_secret_access_key_key  = ""
    gcp_credentials_json_key   = "credentials.json"
    azure_credentials_json_key = ""
    hosted_zone_id             = ""
    region                     = local.region
    provider                   = "gcp"
    subscription_id            = ""
    tenant_id                  = ""
    client_id                  = ""
    project_id                 = var.inputs.cloud_account.attributes.project
  }
  output_interfaces = {}
}
