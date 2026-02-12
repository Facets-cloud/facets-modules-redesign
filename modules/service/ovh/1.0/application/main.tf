locals {
  # Basic configuration
  spec                         = var.values.spec
  advanced_config              = lookup(lookup(var.values, "advanced", {}), "common", {})
  advanced_config_values       = lookup(local.advanced_config, "app_chart", {})
  
  # Image configuration
  image_lookup                 = lookup(var.values.spec.release, "image", "nginx:latest")
  image_id                     = local.image_lookup
  build_id                     = "NA"
  
  # Environment variables
  spec_environment_variables   = lookup(var.values.spec, "env", {})
  include_common_env_variables = lookup(local.advanced_config, "include_common_env_variables", false)
  common_env_vars              = var.environment.common_environment_variables
  
  env_vars = local.include_common_env_variables ? merge(local.common_env_vars, local.spec_environment_variables) : local.spec_environment_variables
  
  # Resource sizing
  size = lookup(lookup(var.values.spec, "runtime", {}), "size", {
    cpu          = "100m"
    cpu_limit    = "500m"
    memory       = "128Mi"
    memory_limit = "512Mi"
  })
  
  cpu          = lookup(local.size, "cpu", "100m")
  cpu_limit    = lookup(local.size, "cpu_limit", local.cpu)
  memory       = lookup(local.size, "memory", "128Mi")
  memory_limit = lookup(local.size, "memory_limit", local.memory)
  
  processed_size = {
    cpu_limit    = local.cpu_limit
    cpu          = local.cpu
    memory_limit = local.memory_limit
    memory       = local.memory
  }
  
  # Workload type and configuration
  type           = lookup(var.values.spec, "type", "application")
  pvcs           = lookup(var.values.spec, "persistent_volume_claims", {})
  instance_count = lookup(lookup(var.values.spec, "runtime", {}), "instance_count", 1)
  
  # StatefulSet PVCs
  sts_pvcs = local.type == "statefulset" ? merge(slice(flatten([
    for idx in range(local.instance_count) : {
      for pvc_name, pvc_spec in local.pvcs : "${pvc_name}-vol-${var.chart_name}-${idx}" => merge(pvc_spec, { index = idx })
  }]), 0, local.instance_count)...) : {}
  
  # Node selection and tolerations
  node_selector   = lookup(local.advanced_config_values, "node_selector", {})
  tolerations     = lookup(local.advanced_config_values, "tolerations", [])
  
  # Containers
  sidecars        = lookup(var.values.spec, "sidecars", {})
  init_containers = lookup(var.values.spec, "init_containers", {})
  
  # Pod distribution
  pod_distribution = lookup(local.advanced_config_values, "pod_distribution", {})
}

resource "helm_release" "app-chart" {
  depends_on = [module.sts-pvc]
  
  name             = "${var.chart_name}-app-chart"
  chart            = "${path.module}/app-chart"
  namespace        = var.namespace
  version          = "0.3.0"
  create_namespace = var.namespace == "default" ? false : true
  timeout          = lookup(local.advanced_config, "timeout", 300)
  wait             = lookup(local.advanced_config, "wait", false)
  atomic           = lookup(local.advanced_config, "atomic", false)
  max_history      = 10
  cleanup_on_fail  = lookup(local.advanced_config, "cleanup_on_fail", true)
  
  values = [
    yamlencode(var.values),
    yamlencode({
      metadata = {
        name        = var.chart_name
        annotations = merge(var.annotations, { buildId = local.build_id })
        labels      = var.labels
      }
      spec = {
        release = {
          image = local.image_id
        }
        runtime = merge(
          lookup(var.values.spec, "runtime", {}),
          {
            size = local.processed_size
          }
        )
      }
    }),
    yamlencode({
      spec = {
        env = local.env_vars
      }
    }),
    yamlencode({
      advanced = {
        common = {
          app_chart = {
            values = {
              tolerations        = local.tolerations
              node_selector      = local.node_selector
              pod_distribution   = local.pod_distribution
              image_pull_secrets = var.registry_secret_objects
              init_containers    = local.init_containers
              sidecars          = local.sidecars
              enable_vpa        = false
            }
          }
        }
      }
    })
  ]
  
  lifecycle {
    ignore_changes = [chart]
  }
}

module "sts-pvc" {
  for_each = local.sts_pvcs
  
  source          = "github.com/Facets-cloud/facets-utility-modules//pvc"
  name            = each.key
  namespace       = var.namespace
  access_modes    = [each.value.access_mode]
  volume_size     = each.value.storage_size
  provisioned_for = "${var.chart_name}-app-chart-${each.value.index}"
  instance_name   = var.chart_name
  kind            = "service"
  additional_labels = merge({
    "app"                        = var.chart_name
    "app.kubernetes.io/name"     = var.chart_name
    "app.kubernetes.io/instance" = "${var.chart_name}-app-chart"
  }, var.labels)
  cloud_tags = var.environment.cloud_tags
}