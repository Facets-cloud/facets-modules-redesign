locals {
  # Core instance spec and platform-provided variables
  spec     = lookup(var.instance, "spec", {})
  metadata = lookup(var.instance, "metadata", {})

  # Platform-provided variables with fallbacks for validation
  # Get project ID from cloud account input dependency
  gcp_cloud_account        = lookup(var.inputs, "gcp_cloud_account", {})
  cloud_account_attributes = lookup(local.gcp_cloud_account, "attributes", {})
  cluster_project          = lookup(local.cloud_account_attributes, "project_id", "validation-project")
  gcp_annotations = {
    "cloud.google.com/neg" = "{\"ingress\":true}"
  }
  gcp_advanced_config       = lookup(lookup(var.instance, "advanced", {}), "gcp", {})
  gcp_cloud_permissions     = lookup(lookup(local.spec, "cloud_permissions", {}), "gcp", {})
  iam_arns                  = lookup(local.gcp_cloud_permissions, "roles", lookup(local.gcp_advanced_config, "iam", {}))
  sa_name                   = lower(var.instance_name)
  spec_type                 = lookup(local.spec, "type", "application")
  actions_required_vars_set = can(var.instance.kind) && can(var.instance.version) && can(var.instance.flavor) && !contains(["cronjob", "job"], local.spec_type)

  enable_actions             = lookup(var.instance.spec, "enable_actions", true) && local.actions_required_vars_set ? true : false
  enable_deployment_actions  = local.enable_actions && local.spec_type == "application" ? 1 : 0
  enable_statefulset_actions = local.enable_actions && local.spec_type == "statefulset" ? 1 : 0

  namespace = lookup(local.metadata, "namespace", null) == null ? var.environment.namespace : lookup(local.metadata, "namespace", var.environment.namespace)
  annotations = merge(
    local.gcp_annotations,
    length(local.iam_arns) > 0 ? { "iam.gke.io/gcp-service-account" = module.gcp-workload-identity.0.gcp_service_account_email } : {},
    lookup(local.metadata, "annotations", {}),
    local.enable_alb_backend_config ? { "cloud.google.com/backend-config" = "{\"default\": \"${lower(var.instance_name)}\"}" } : {}
  )
  roles                     = { for key, val in local.iam_arns : val.role => { role = val.role, condition = lookup(val, "condition", {}) } }
  labels                    = lookup(local.metadata, "labels", {})
  backend_config            = lookup(local.gcp_advanced_config, "backend_config", {})
  enable_alb_backend_config = lookup(local.backend_config, "enabled", false)
  runtime                   = lookup(local.spec, "runtime", {})
  backendConfig = {
    apiVersion = "cloud.google.com/v1",
    kind       = "BackendConfig",
    spec = merge({
      healthCheck = {
        checkIntervalSec   = lookup(lookup(lookup(local.backend_config, "spec", {}), "healthCheck", {}), "checkIntervalSec", 10),
        timeoutSec         = lookup(lookup(lookup(local.backend_config, "spec", {}), "healthCheck", {}), "timeoutSec", lookup(lookup(local.runtime, "health_checks", {}), "timeout", 5)),
        healthyThreshold   = lookup(lookup(lookup(local.backend_config, "spec", {}), "healthCheck", {}), "healthyThreshold", 2),
        unhealthyThreshold = lookup(lookup(lookup(local.backend_config, "spec", {}), "healthCheck", {}), "unhealthyThreshold", 2),
        type               = lookup(lookup(lookup(local.backend_config, "spec", {}), "healthCheck", {}), "type", "HTTP"),
        requestPath        = lookup(lookup(lookup(local.backend_config, "spec", {}), "healthCheck", {}), "requestPath", lookup(lookup(local.runtime, "health_checks", {}), "readiness_url", "/")),
      }
    }, lookup(local.backend_config, "spec", {}))
  }
  resource_type = "service"
  resource_name = var.instance_name

  # Check if VPA is available and configure accordingly
  vpa_available = lookup(var.inputs, "vpa_details", null) != null

  # KEDA configuration
  autoscaling_config  = lookup(local.runtime, "autoscaling", {})
  autoscaling_enabled = lookup(local.autoscaling_config, "enabled", true)
  scaling_on          = lookup(local.autoscaling_config, "scaling_on", "CPU")
  enable_keda         = local.autoscaling_enabled && local.scaling_on == "KEDA"

  # Build KEDA configuration object when KEDA is enabled
  keda_config = jsondecode(local.enable_keda ? jsonencode({
    polling_interval = lookup(local.autoscaling_config, "keda_polling_interval", 30)
    cooldown_period  = lookup(local.autoscaling_config, "keda_cooldown_period", 300)
    fallback = lookup(local.autoscaling_config, "keda_fallback", {
      failureThreshold = 3
      replicas         = 6
    })
    advanced = lookup(local.autoscaling_config, "keda_advanced", {
      restoreToOriginalReplicaCount = false
    })
    triggers = [for trigger in values(lookup(local.autoscaling_config, "keda_triggers", {})) : trigger.configuration]
  }) : jsonencode({}))

  # Configure pod distribution directly from spec
  enable_host_anti_affinity = lookup(local.spec, "enable_host_anti_affinity", false)

  # Determine final pod_distribution configuration
  pod_distribution = {
    "facets-pod-topology-spread" = {
      max_skew           = 1
      when_unsatisfiable = "ScheduleAnyway"
      topology_key       = var.inputs.kubernetes_node_pool_details.topology_spread_key
    }
  }

  # Create instance configuration with VPA settings, topology spread constraints, and KEDA configuration
  instance = merge(var.instance, {
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
                    pod_distribution_enabled = true
                    pod_distribution         = local.pod_distribution
                  },
                  # Add KEDA configuration when enabled
                  local.enable_keda ? { keda = local.keda_config } : {},

                  {
                    image_pull_secrets = lookup(lookup(lookup(var.inputs, "artifactories", {}), "attributes", {}), "registry_secrets_list", [])
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
  count           = length(local.iam_arns) > 0 ? 1 : 0
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = false
  globally_unique = true
  resource_name   = local.resource_name
  resource_type   = local.resource_type
  limit           = 33
  environment     = var.environment
  prefix          = "a"
}

module "gcp-workload-identity" {
  count               = length(local.iam_arns) > 0 ? 1 : 0
  source              = "./gcp_workload-identity/workload-identity"
  name                = module.sr-name.0.name
  k8s_sa_name         = "${local.sa_name}-sa"
  namespace           = local.namespace
  project_id          = local.cluster_project
  roles               = local.roles
  use_existing_k8s_sa = true
  annotate_k8s_sa     = false
}

module "app-helm-chart" {
  depends_on = [
    module.gcp-workload-identity
  ]
  source         = "github.com/Facets-cloud/facets-utility-modules//application/2.0"
  namespace      = local.namespace
  chart_name     = lower(var.instance_name)
  values         = local.instance
  annotations    = local.annotations
  labels         = local.labels
  environment    = var.environment
  inputs         = var.inputs
  vpa_release_id = lookup(lookup(lookup(var.inputs, "vpa_details", {}), "attributes", {}), "helm_release_id", "")
}

module "backend_config" {
  count           = local.enable_alb_backend_config ? 1 : 0
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  namespace       = local.namespace
  advanced_config = {}
  data            = local.backendConfig
  name            = lower(var.instance_name)
}
