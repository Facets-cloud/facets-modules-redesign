locals {
  # Core instance spec
  spec = lookup(var.instance, "spec", {})

  azure_advanced_config     = lookup(lookup(var.instance, "advanced", {}), "azure", {})
  azure_cloud_permissions   = lookup(lookup(local.spec, "cloud_permissions", {}), "azure", {})
  azure_advanced_iam        = lookup(lookup(lookup(var.instance, "advanced", {}), "azure", {}), "iam", {})
  iam_arns                  = lookup(local.azure_cloud_permissions, "roles", local.azure_advanced_iam)
  sa_name                   = lower(var.instance_name)
  spec_type                 = lookup(local.spec, "type", "application")
  actions_required_vars_set = can(var.instance.kind) && can(var.instance.version) && can(var.instance.flavor) && !contains(["cronjob", "job"], local.spec_type)

  enable_actions             = lookup(var.instance.spec, "enable_actions", true) && local.actions_required_vars_set ? true : false
  enable_deployment_actions  = local.enable_actions && local.spec_type == "application" ? 1 : 0
  enable_statefulset_actions = local.enable_actions && local.spec_type == "statefulset" ? 1 : 0

  namespace   = var.environment.namespace
  annotations = {}
  labels = merge(
    length(local.iam_arns) > 0 ? { aadpodidbinding = azurerm_user_assigned_identity.service_user_iam.0.name } : {}
  )
  name          = lower(var.instance_name)
  resource_type = "service"
  resource_name = var.instance_name

  image_pull_secrets = lookup(lookup(lookup(var.inputs, "artifactories", {}), "attributes", {}), "registry_secrets_list", [])

  # Check if VPA is available and configure accordingly
  vpa_available = lookup(var.inputs, "vpa_details", null) != null

  # Configure pod distribution directly from spec
  enable_host_anti_affinity = lookup(local.spec, "enable_host_anti_affinity", false)
  pod_distribution_enabled  = lookup(local.spec, "pod_distribution_enabled", false)
  pod_distribution_spec     = lookup(local.spec, "pod_distribution", {})

  # Convert pod_distribution object to array format expected by helm chart
  pod_distribution_array = [
    for key, config in local.pod_distribution_spec : {
      topology_key         = config.topology_key
      when_unsatisfiable   = config.when_unsatisfiable
      max_skew             = config.max_skew
      node_taints_policy   = lookup(config, "node_taints_policy", null)
      node_affinity_policy = lookup(config, "node_affinity_policy", null)
    }
  ]

  # Determine final pod_distribution configuration
  pod_distribution = local.pod_distribution_enabled ? (
    length(local.pod_distribution_spec) > 0 ? local.pod_distribution_array : (
      local.enable_host_anti_affinity ? [{
        topology_key       = "kubernetes.io/hostname"
        when_unsatisfiable = "DoNotSchedule"
        max_skew           = 1
      }] : []
    )
  ) : []

  # Create instance configuration with VPA settings and topology spread constraints
  instance_with_vpa_config = merge(var.instance, {
    advanced = merge(
      lookup(var.instance, "advanced", {}),
      {
        common = merge(
          lookup(lookup(var.instance, "advanced", {}), "common", {}),
          {
            app_chart = merge(
              lookup(lookup(lookup(var.instance, "advanced", {}), "common", {}), "app_chart", {}),
              {
                values = merge(
                  lookup(lookup(lookup(lookup(var.instance, "advanced", {}), "common", {}), "app_chart", {}), "values", {}),
                  {
                    enable_vpa = local.vpa_available
                    # Configure pod distribution for the application chart
                    pod_distribution_enabled = local.pod_distribution_enabled
                    pod_distribution         = local.pod_distribution
                  },
                  {
                    image_pull_secrets = local.image_pull_secrets
                  }
                )
              }
            )
          }
        )
      }
    )
  })

  # Network details
  network_attributes = lookup(var.inputs.network_details, "attributes", {})
  location           = lookup(local.network_attributes, "location", "")
  resource_group     = lookup(local.network_attributes, "resource_group", "")
  subscription_id    = lookup(local.network_attributes, "subscription_id", "")
}

resource "azurerm_user_assigned_identity" "service_user_iam" {
  count               = length(local.iam_arns) > 0 ? 1 : 0
  location            = local.location
  name                = "${local.name}-service-identity"
  resource_group_name = local.resource_group
  tags                = var.environment.cloud_tags
}

resource "azurerm_role_assignment" "service_user_iam_roles_assignment" {
  for_each             = length(local.iam_arns) > 0 ? local.iam_arns : {}
  principal_id         = azurerm_user_assigned_identity.service_user_iam.0.principal_id
  scope                = local.subscription_id
  role_definition_name = each.value.role
  description          = "Will be used by service module to assign cloud credentials to applications"
}

module "azure-aadpod-identity" {
  depends_on      = [azurerm_user_assigned_identity.service_user_iam, azurerm_role_assignment.service_user_iam_roles_assignment]
  count           = length(local.iam_arns) > 0 ? 1 : 0
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = local.name
  namespace       = local.namespace
  advanced_config = {}
  data = {
    apiVersion = "aadpodidentity.k8s.io/v1"
    kind       = "AzureIdentity"
    metadata = {
      name      = local.name
      namespace = local.namespace
    }
    spec = {
      type       = 0
      resourceID = azurerm_user_assigned_identity.service_user_iam.0.id
      clientID   = azurerm_user_assigned_identity.service_user_iam.0.client_id
    }
  }
}

module "azure-aadpod-identity-binding" {
  depends_on      = [azurerm_user_assigned_identity.service_user_iam, azurerm_role_assignment.service_user_iam_roles_assignment]
  count           = length(local.iam_arns) > 0 ? 1 : 0
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = "${local.name}-binding"
  namespace       = local.namespace
  advanced_config = {}
  data = {
    apiVersion = "aadpodidentity.k8s.io/v1"
    kind       = "AzureIdentityBinding"
    metadata = {
      name      = "${local.name}-binding"
      namespace = local.namespace
    }
    spec = {
      azureIdentity = local.name
      selector      = azurerm_user_assigned_identity.service_user_iam.0.name
    }
  }
}

module "app-helm-chart" {
  depends_on = [
    module.azure-aadpod-identity,
    module.azure-aadpod-identity-binding
  ]
  source         = "github.com/Facets-cloud/facets-utility-modules//application/2.0"
  namespace      = local.namespace
  chart_name     = local.name
  values         = local.instance_with_vpa_config
  annotations    = local.annotations
  labels         = local.labels
  environment    = var.environment
  inputs         = var.inputs
  vpa_release_id = lookup(lookup(lookup(var.inputs, "vpa_details", {}), "attributes", {}), "helm_release_id", "")
}
