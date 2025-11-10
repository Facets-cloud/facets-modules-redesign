# Data source for existing managed identity (if using existing)
data "azurerm_user_assigned_identity" "existing" {
  count = local.use_existing_identity ? 1 : 0

  name                = regex("/providers/Microsoft.ManagedIdentity/userAssignedIdentities/(.+)$", local.existing_identity_id)[0]
  resource_group_name = regex("/resourceGroups/(.+)/providers/Microsoft.ManagedIdentity", local.existing_identity_id)[0]
}

# Azure User-Assigned Managed Identity (equivalent to GCP Service Account)
resource "azurerm_user_assigned_identity" "main" {
  count = local.use_existing_identity ? 0 : 1

  name                = local.generated_identity_name
  resource_group_name = local.resource_group_name
  location            = local.location
  tags                = local.tags
}

# Kubernetes Service Account with workload identity annotation
resource "kubernetes_service_account" "main" {
  count = local.use_existing_k8s_sa ? 0 : 1

  automount_service_account_token = local.automount_service_account_token

  metadata {
    name      = local.k8s_sa_name
    namespace = local.k8s_sa_namespace
    annotations = {
      "azure.workload.identity/client-id" = local.managed_identity_client_id
    }
    labels = {
      "azure.workload.identity/use" = "true"
      resource_type                 = "workload_identity"
      resource_name                 = var.instance_name
    }
  }

  depends_on = [
    azurerm_user_assigned_identity.main
  ]
}

# Annotate existing Kubernetes ServiceAccount (if using existing)
resource "null_resource" "annotate_k8s_sa" {
  count = local.use_existing_k8s_sa && local.annotate_k8s_sa ? 1 : 0

  triggers = {
    cluster_auth  = base64encode(jsonencode(var.inputs.aks_cluster))
    ksa_namespace = local.k8s_sa_namespace
    ksa_name      = local.k8s_sa_name
    client_id     = local.managed_identity_client_id
  }

  provisioner "local-exec" {
    when    = create
    command = <<EOT
    cat > "${local.kubeconfig_filename}" << 'EOF'
${local.kubeconfig_content}
EOF

    KUBECONFIG="${local.kubeconfig_filename}" kubectl annotate --overwrite sa -n ${self.triggers.ksa_namespace} ${self.triggers.ksa_name} azure.workload.identity/client-id=${self.triggers.client_id}
    KUBECONFIG="${local.kubeconfig_filename}" kubectl label --overwrite sa -n ${self.triggers.ksa_namespace} ${self.triggers.ksa_name} azure.workload.identity/use=true
    EOT
  }
}

# Federated Identity Credential (establishes trust between AKS OIDC and Managed Identity)
resource "azurerm_federated_identity_credential" "main" {
  name                = local.federated_credential_name
  resource_group_name = local.resource_group_name
  parent_id           = local.managed_identity_id
  audience            = [local.federated_credential_audience]
  issuer              = local.oidc_issuer_url
  subject             = local.federated_subject

  depends_on = [
    azurerm_user_assigned_identity.main,
    kubernetes_service_account.main
  ]
}

# Azure Role Assignments for the Managed Identity
resource "azurerm_role_assignment" "main" {
  for_each = local.role_assignments_map

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_id
  principal_id         = local.managed_identity_principal_id

  depends_on = [
    azurerm_user_assigned_identity.main
  ]
}