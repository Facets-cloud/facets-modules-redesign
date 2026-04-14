# ── Azure Storage Account for Loki log data ───────────────────────────────────
resource "azurerm_storage_account" "main" {
  name                     = local.storage_account_name
  resource_group_name      = local.resource_group_name
  location                 = local.location
  account_tier             = local.account_tier
  account_replication_type = local.replication_type
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = local.enable_versioning
  }

  tags = local.all_tags

  lifecycle {
    prevent_destroy = true
  }
}

# ── Blob container for Loki chunks and indices ────────────────────────────────
resource "azurerm_storage_container" "loki" {
  name                  = local.container_name
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# ── Lifecycle management policy (only created when retention_days > 0) ────────
resource "azurerm_storage_management_policy" "loki_retention" {
  count = local.has_retention ? 1 : 0

  storage_account_id = azurerm_storage_account.main.id

  rule {
    name    = "loki-data-expiry"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = local.retention_days
      }
    }
  }

  depends_on = [azurerm_storage_account.main]
}

# ── User-Assigned Managed Identity for Loki workload identity ─────────────────
resource "azurerm_user_assigned_identity" "main" {
  name                = local.identity_name
  resource_group_name = local.resource_group_name
  location            = local.location
  tags                = local.all_tags
}

# ── Storage Blob Data Contributor: grants the managed identity read/write/delete
#    on all blobs in the storage account (Azure RBAC equivalent of the S3 IAM policy) ──
resource "azurerm_role_assignment" "storage_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.main.principal_id

  depends_on = [azurerm_user_assigned_identity.main]
}

# ── Federated Identity Credential: trusts the AKS OIDC issuer to let the
#    specified K8s service account impersonate the managed identity ─────────────
resource "azurerm_federated_identity_credential" "main" {
  name                = local.federated_credential_name
  resource_group_name = local.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = local.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.main.id
  subject             = "system:serviceaccount:${local.k8s_sa_namespace}:${local.k8s_sa_name}"

  depends_on = [azurerm_user_assigned_identity.main]
}

# ── Kubernetes Service Account annotated for Azure Workload Identity ───────────
# Loki pods must reference this service account to receive Azure AD tokens.
resource "kubernetes_service_account" "loki" {
  metadata {
    name      = local.k8s_sa_name
    namespace = local.k8s_sa_namespace

    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.main.client_id
    }

    labels = {
      "azure.workload.identity/use" = "true"
      resource_type                 = "loki_blob"
      resource_name                 = var.instance_name
    }
  }

  automount_service_account_token = false

  depends_on = [
    azurerm_user_assigned_identity.main,
    azurerm_federated_identity_credential.main,
  ]
}
