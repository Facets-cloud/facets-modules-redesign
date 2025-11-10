locals {
  spec = var.instance.spec

  # Identity configuration
  identity_name               = lookup(var.instance.spec, "identity_name", null)
  use_existing_identity       = lookup(var.instance.spec, "use_existing_identity", false)
  existing_identity_id        = lookup(var.instance.spec, "existing_identity_resource_id", null)
  existing_identity_client_id = lookup(var.instance.spec, "existing_identity_client_id", null)

  # Generate unique name if identity_name not provided
  generated_identity_name = local.identity_name == null || local.identity_name == "" ? "workload-id-${var.environment.unique_name}-${var.instance_name}" : local.identity_name

  # Kubernetes ServiceAccount configuration
  k8s_sa_name                     = lookup(var.instance.spec, "service_account_name", "workload-identity-sa")
  k8s_sa_namespace                = lookup(var.instance.spec, "service_account_namespace", "default")
  use_existing_k8s_sa             = lookup(var.instance.spec, "use_existing_k8s_sa", false)
  annotate_k8s_sa                 = lookup(var.instance.spec, "annotate_k8s_sa", true)
  automount_service_account_token = lookup(var.instance.spec, "automount_service_account_token", false)

  # Federated credential configuration
  federated_credential_name     = lookup(var.instance.spec, "federated_credential_name", "workload-identity-federation")
  federated_credential_audience = lookup(var.instance.spec, "federated_credential_audience", "api://AzureADTokenExchange")

  # Azure configuration
  resource_group_name = var.inputs.aks_cluster.resource_group_name
  location            = var.inputs.aks_cluster.location
  oidc_issuer_url     = var.inputs.aks_cluster.oidc_issuer_url

  # Tags
  tags = lookup(var.instance.spec, "tags", {})

  # Role assignments
  role_assignments_map = lookup(var.instance.spec, "role_assignments", {})

  # Computed values
  managed_identity_client_id    = local.use_existing_identity ? local.existing_identity_client_id : azurerm_user_assigned_identity.main[0].client_id
  managed_identity_id           = local.use_existing_identity ? local.existing_identity_id : azurerm_user_assigned_identity.main[0].id
  managed_identity_principal_id = local.use_existing_identity ? null : azurerm_user_assigned_identity.main[0].principal_id

  # Kubernetes ServiceAccount subject for federated credential
  federated_subject = "system:serviceaccount:${local.k8s_sa_namespace}:${local.k8s_sa_name}"

  # Kubeconfig for kubectl operations (when annotating existing K8s SA)
  kubeconfig_content = sensitive(yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      cluster = {
        certificate-authority-data = base64encode(var.inputs.aks_cluster.cluster_ca_certificate)
        server                     = var.inputs.aks_cluster.cluster_endpoint
      }
      name = "aks-cluster"
    }]
    contexts = [{
      context = {
        cluster = "aks-cluster"
        user    = "aks-user"
      }
      name = "aks-context"
    }]
    current-context = "aks-context"
    users = [{
      name = "aks-user"
      user = {
        exec = {
          apiVersion = var.inputs.aks_cluster.kubernetes_provider_exec.api_version
          command    = var.inputs.aks_cluster.kubernetes_provider_exec.command
          args       = var.inputs.aks_cluster.kubernetes_provider_exec.args
        }
      }
    }]
  }))
  kubeconfig_filename = "/tmp/${var.environment.unique_name}_azure_workload_identity_${var.instance_name}.yaml"
}
