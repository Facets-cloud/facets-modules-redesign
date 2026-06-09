locals {
  # Core instance spec
  spec    = lookup(var.instance, "spec", {})
  sa_name = lower(var.instance_name)

  # Spec type for actions (application, cronjob, job, statefulset)
  spec_type                 = lookup(local.spec, "type", "application")
  actions_required_vars_set = can(var.instance.kind) && can(var.instance.version) && can(var.instance.flavor) && !contains(["cronjob", "job"], local.spec_type)

  enable_actions             = lookup(var.instance.spec, "enable_actions", true) && local.actions_required_vars_set ? true : false
  enable_deployment_actions  = local.enable_actions && local.spec_type == "application" ? 1 : 0
  enable_statefulset_actions = local.enable_actions && local.spec_type == "statefulset" ? 1 : 0

  namespace     = var.environment.namespace
  annotations   = {}
  labels        = {}
  resource_type = "service"
  resource_name = var.instance_name

  image_pull_secrets = try(var.inputs.artifactories.attributes.registry_secrets_list, [])

  # Transform taints from object format to string format for utility module compatibility
  kubernetes_node_pool_details = lookup(var.inputs, "kubernetes_node_pool_details", {})
  node_pool_taints             = lookup(local.kubernetes_node_pool_details, "taints", [])
  node_pool_labels             = lookup(local.kubernetes_node_pool_details, "node_selector", {})

  # Convert taints from {key: "key", value: "value", effect: "effect"} to "key=value:effect" format
  transformed_taints = [
    for taint_name, taint_config in local.node_pool_taints :
    "${taint_config.key}=${taint_config.value}:${taint_config.effect}"
  ]

  # Create modified inputs with transformed taints
  modified_inputs = merge(var.inputs, {
    kubernetes_node_pool_details = merge(local.kubernetes_node_pool_details, {
      taints        = local.transformed_taints
      node_selector = local.node_pool_labels
    })
  })

  # Check if VPA is available and configure accordingly
  vpa_available = try(var.inputs.vpa_details != null, false)

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
}

module "sr-name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = false
  globally_unique = true
  resource_name   = local.resource_name
  resource_type   = local.resource_type
  limit           = 60
  environment     = var.environment
}

module "app-helm-chart" {
  source         = "github.com/Facets-cloud/facets-utility-modules//application/2.0"
  namespace      = local.namespace
  chart_name     = lower(var.instance_name)
  values         = local.instance_with_vpa_config
  annotations    = local.annotations
  labels         = local.labels
  environment    = var.environment
  inputs         = local.modified_inputs
  vpa_release_id = try(var.inputs.vpa_details.attributes.helm_release_id, "")
}
