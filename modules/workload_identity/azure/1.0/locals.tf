locals {
  spec = var.instance.spec

  # Identity configuration
  identity_name         = lookup(var.instance.spec, "identity_name", null)
  use_existing_identity = lookup(var.instance.spec, "use_existing_identity", false)
  existing_identity_id  = lookup(var.instance.spec, "existing_identity_resource_id", null)

  # Generate unique name if identity_name not provided
  generated_identity_name = local.identity_name == null || local.identity_name == "" ? "workload-id-${var.environment.unique_name}-${var.instance_name}" : local.identity_name

  # Kubernetes ServiceAccount configuration
  k8s_sa_name                     = lookup(var.instance.spec, "service_account_name", "workload-identity-sa")
  k8s_sa_namespace                = lookup(var.instance.spec, "service_account_namespace", "default")
  use_existing_k8s_sa             = lookup(var.instance.spec, "use_existing_k8s_sa", false)
  annotate_k8s_sa                 = lookup(var.instance.spec, "annotate_k8s_sa", true)
  automount_service_account_token = lookup(var.instance.spec, "automount_service_account_token", false)

  # Azure configuration - access via attributes
  aks_attributes      = lookup(var.inputs.aks_cluster, "attributes", {})
  resource_group_name = lookup(local.aks_attributes, "resource_group_name", "")
  location            = lookup(local.aks_attributes, "cluster_location", "")

  # Tags
  tags = lookup(var.instance.spec, "tags", {})

  # Role assignments
  role_assignments_map = lookup(var.instance.spec, "role_assignments", {})

  # Computed values
  managed_identity_client_id    = local.use_existing_identity ? data.azurerm_user_assigned_identity.existing[0].client_id : azurerm_user_assigned_identity.main[0].client_id
  managed_identity_id           = local.use_existing_identity ? local.existing_identity_id : azurerm_user_assigned_identity.main[0].id
  managed_identity_principal_id = local.use_existing_identity ? data.azurerm_user_assigned_identity.existing[0].principal_id : azurerm_user_assigned_identity.main[0].principal_id

  # Kubeconfig for kubectl operations (when annotating existing K8s SA)
  kubeconfig_content = sensitive(yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      cluster = {
        certificate-authority-data = base64encode(lookup(local.aks_attributes, "cluster_ca_certificate", ""))
        server                     = lookup(local.aks_attributes, "cluster_endpoint", "")
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
        client-certificate-data = base64encode(lookup(local.aks_attributes, "client_certificate", ""))
        client-key-data         = base64encode(lookup(local.aks_attributes, "client_key", ""))
      }
    }]
  }))
  kubeconfig_filename = "/tmp/${var.environment.unique_name}_azure_workload_identity_${var.instance_name}.yaml"
}
