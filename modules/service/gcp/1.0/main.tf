locals {
  # Core instance spec and platform-provided variables
  spec = lookup(var.instance, "spec", {})

  iam_enabled = local.gcp_iam_arns > 0 || local.aws_iam_arns > 0
  cluster_project          = lookup(local.cloud_account_attributes, "project_id", "validation-project")
  gcp_annotations = {
    "cloud.google.com/neg" = "{\"ingress\":true}"
  }
  sa_name                   = lower(var.instance_name)
  spec_type                 = lookup(local.spec, "type", "application")

  release_metadata_labels = {
    "facets.cloud/blueprint_version" = tostring(lookup(local.release_metadata.metadata, "blueprint_version", "NA")) == null ? "NA" : tostring(lookup(local.release_metadata.metadata, "blueprint_version", "NA"))
    "facets.cloud/override_version"  = tostring(lookup(local.release_metadata.metadata, "override_version", "NA")) == null ? "NA" : tostring(lookup(local.release_metadata.metadata, "override_version", "NA"))
  }
  namespace = lookup(var.instance.metadata, "namespace", null) == null ? var.environment.namespace : var.instance.metadata.namespace
  annotations = merge(
    local.gcp_annotations,
    # Add GCP service account annotation if GCP roles OR AWS IAM ARNs are specified
    local.iam_enabled ? { "iam.gke.io/gcp-service-account" = module.gcp-workload-identity.0.gcp_service_account_email } : {},
    lookup(var.instance.metadata, "annotations", {}),
    local.enable_alb_backend_config ? { "cloud.google.com/backend-config" = "{\"default\": \"${lower(var.instance_name)}\"}" } : {}
  )
  labels                    = merge(lookup(var.instance.metadata, "labels", {}), local.release_metadata_labels)
  runtime                   = lookup(local.spec, "runtime", {})
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
    spec = merge(
      local.spec,
      {
        env = merge(
          lookup(local.spec, "env", {}),
          local.enable_aws_access ? local.aws_env_vars : {}
        )
      }
    )
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
                    image_pull_secrets = var.inputs.artifactories.attributes.registry_secrets_list
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

module "app-helm-chart" {
  depends_on = [
    module.gcp-workload-identity
  ]
  source         = "./application"
  namespace      = local.namespace
  chart_name     = lower(var.instance_name)
  values         = local.instance
  annotations    = local.annotations
  labels         = local.labels
  cluster        = var.cluster
  environment    = var.environment
  inputs         = var.inputs
  vpa_release_id = lookup(lookup(lookup(var.inputs, "vpa_details", {}), "attributes", {}), "helm_release_id", "")
}
