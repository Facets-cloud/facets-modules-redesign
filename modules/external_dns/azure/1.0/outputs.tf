locals {
  output_attributes = {
    # Secret information (created by this module)
    secret_name                = kubernetes_secret.external_dns_azure_secret.metadata[0].name
    secret_namespace           = local.namespace
    azure_credentials_json_key = "client-secret"

    # Cloud provider identifier
    provider = "azure"

    # Azure account details (from cloud_account module via locals)
    subscription_id     = local.subscription_id
    tenant_id           = local.tenant_id
    client_id           = local.client_id
    resource_group_name = local.resource_group_name

    # Region (from AKS cluster)
    region = local.region
  }
  output_interfaces = {}
}