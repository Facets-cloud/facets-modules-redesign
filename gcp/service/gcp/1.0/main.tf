locals {
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

  release_metadata_labels = {
    "facets.cloud/blueprint_version" = tostring(lookup(local.release_metadata.metadata, "blueprint_version", "NA")) == null ? "NA" : tostring(lookup(local.release_metadata.metadata, "blueprint_version", "NA"))
    "facets.cloud/override_version"  = tostring(lookup(local.release_metadata.metadata, "override_version", "NA")) == null ? "NA" : tostring(lookup(local.release_metadata.metadata, "override_version", "NA"))
  }
  namespace = lookup(var.instance.metadata, "namespace", null) == null ? var.environment.namespace : var.instance.metadata.namespace
  annotations = merge(
    local.gcp_annotations,
    length(local.iam_arns) > 0 ? { "iam.gke.io/gcp-service-account" = module.gcp-workload-identity.0.gcp_service_account_email } : {},
    lookup(var.instance.metadata, "annotations", {}),
    local.enable_alb_backend_config ? { "cloud.google.com/backend-config" = "{\"default\": \"${lower(var.instance_name)}\"}" } : {}
  )
  roles                     = { for key, val in local.iam_arns : val.role => { role = val.role, condition = lookup(val, "condition", {}) } }
  labels                    = merge(lookup(var.instance.metadata, "labels", {}), local.release_metadata_labels)
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

  from_artifactories      = lookup(lookup(lookup(var.inputs, "artifactories", {}), "attributes", {}), "registry_secrets_list", [])
  from_kubernetes_cluster = []

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
  project_id          = var.cluster.project
  roles               = local.roles
  use_existing_k8s_sa = true
  annotate_k8s_sa     = false
}

module "app-helm-chart" {
  depends_on = [
    module.gcp-workload-identity
  ]
  source                  = "github.com/Facets-cloud/facets-utility-modules//application"
  namespace               = local.namespace
  chart_name              = lower(var.instance_name)
  values                  = local.instance_with_vpa_config
  annotations             = local.annotations
  registry_secret_objects = length(local.from_artifactories) > 0 ? local.from_artifactories : local.from_kubernetes_cluster
  cc_metadata             = var.cc_metadata
  labels                  = local.labels
  baseinfra               = var.baseinfra
  cluster                 = var.cluster
  environment             = var.environment
  inputs                  = var.inputs
  vpa_release_id          = lookup(lookup(lookup(var.inputs, "vpa_details", {}), "attributes", {}), "helm_release_id", "")
}

module "backend_config" {
  count           = local.enable_alb_backend_config ? 1 : 0
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  namespace       = local.namespace
  advanced_config = {}
  data            = local.backendConfig
  name            = lower(var.instance_name)
}
