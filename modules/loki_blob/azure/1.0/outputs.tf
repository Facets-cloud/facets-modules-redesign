locals {
  output_attributes = {
    # Storage
    storage_account_name = azurerm_storage_account.main.name
    storage_account_id   = azurerm_storage_account.main.id
    container_name       = azurerm_storage_container.loki.name
    endpoint_suffix      = local.endpoint_suffix

    # Managed identity (for Helm chart annotations and Loki storage config)
    managed_identity_id           = azurerm_user_assigned_identity.main.id
    managed_identity_client_id    = azurerm_user_assigned_identity.main.client_id
    managed_identity_principal_id = azurerm_user_assigned_identity.main.principal_id

    # Kubernetes service account (for Loki Helm chart serviceAccount config)
    service_account_name      = local.k8s_sa_name
    service_account_namespace = local.k8s_sa_namespace

    # Loki configuration hints
    query_timeout = local.query_timeout
  }

  output_interfaces = {}
}
