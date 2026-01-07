locals {
  output_attributes = {
    secret_name                = kubernetes_secret.external_dns_azure_secret.metadata[0].name
    secret_namespace           = local.namespace
    aws_access_key_id_key      = ""
    aws_secret_access_key_key  = ""
    gcp_credentials_json_key   = ""
    azure_credentials_json_key = "client-secret"
    hosted_zone_id             = ""
    region                     = ""
    provider                   = "azure"
    subscription_id            = var.inputs.cloud_account.attributes.subscription_id
    tenant_id                  = var.inputs.cloud_account.attributes.tenant_id
    client_id                  = var.inputs.cloud_account.attributes.client_id
    resource_group_name        = var.inputs.cloud_account.attributes.resource_group_name
    project_id                 = ""
  }
  output_interfaces = {}
}