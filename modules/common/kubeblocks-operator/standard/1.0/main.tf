locals {
  # Get node pool details from input
  node_pool_input  = lookup(var.inputs, "node_pool", {})
  node_pool_attrs  = lookup(local.node_pool_input, "attributes", {})
  node_selector    = lookup(local.node_pool_attrs, "node_selector", {})
  node_pool_taints = lookup(local.node_pool_attrs, "taints", [])

  # Convert taints from {key, value, effect} to tolerations format
  tolerations = [
    for taint in local.node_pool_taints : {
      key      = taint.key
      operator = "Equal"
      value    = taint.value
      effect   = taint.effect
    }
  ]

  namespace = "kb-system"

  # HA settings
  ha_config  = lookup(var.instance.spec, "high_availability", {})
  replicas   = lookup(local.ha_config, "replicas", 1)
  enable_pdb = lookup(local.ha_config, "enable_pdb", false)
}

# KubeBlocks Helm Release
# CRDs are installed via the kubernetes_job above (not managed in state)
resource "helm_release" "kubeblocks" {
  name       = "kubeblocks"
  repository = "https://apecloud.github.io/helm-charts"
  chart      = "kubeblocks"
  version    = var.instance.spec.version
  namespace  = local.namespace

  create_namespace = true  # Helm will create the namespace if it doesn't exist
  wait             = false # Disable wait to prevent destroy hang issues
  wait_for_jobs    = false # Disable wait_for_jobs to prevent timeout issues
  timeout          = 600
  max_history      = 10

  # Skip CRDs - installed via the kubernetes_job above
  skip_crds = true

  # Allow resource replacement during upgrades
  replace = true

  values = [
    yamlencode(merge(
      {
        # Addon controller is disabled - addons are installed via database_addons configuration
        # This prevents webhook-created Addon CRs that would block namespace deletion
        addonController = {
          enabled = false
        }

        autoInstalledAddons = [] # Disable auto-installed addons

        # Prevent retention of addon resources on uninstall
        # This ensures Helm deletes addon resources during destroy
        keepAddons = false

        # Remove global resources on uninstall
        # This prevents orphaned cluster-scoped resources
        keepGlobalResources = false

        upgradeAddons = false # Prevent automatic addon upgrades

        dataProtection = {
          enabled      = true # Enable data protection features by default
          tolerations  = local.tolerations
          nodeSelector = local.node_selector
        }
        featureGates = {
          inPlacePodVerticalScaling = {
            # ENABLED by default - feature is GA in Kubernetes 1.35, Beta (default enabled) since 1.33
            # Allows zero-downtime resource updates without pod restarts
            # Ref: https://kubernetes.io/docs/reference/command-line-tools-reference/feature-gates/
            enabled = true
          }
        }
        resources = {
          limits = {
            cpu    = lookup(lookup(var.instance.spec, "resources", {}), "cpu_limit", "1000m")
            memory = lookup(lookup(var.instance.spec, "resources", {}), "memory_limit", "1Gi")
          }
          requests = {
            cpu    = lookup(lookup(var.instance.spec, "resources", {}), "cpu_request", "500m")
            memory = lookup(lookup(var.instance.spec, "resources", {}), "memory_request", "512Mi")
          }
        }
        image = {
          pullPolicy = "IfNotPresent"
        }
        # Add tolerations to allow scheduling on spot instances and other tainted nodes
        tolerations = local.tolerations
        # Add node selector for node pool affinity
        nodeSelector = local.node_selector

        # HA settings - replicas and PDB
        replicaCount = local.replicas
        podDisruptionBudget = local.enable_pdb ? {
          minAvailable = 1
        } : {}

      },
    ))
  ]

  depends_on = [kubernetes_job.install_crds]

  lifecycle {
    prevent_destroy = true
  }
}

resource "time_sleep" "wait_for_kubeblocks" {
  create_duration = "60s"
  depends_on      = [helm_release.kubeblocks]
}

# Time sleep resource to ensure proper cleanup during destroy
# This gives custom resources time to be deleted before operator is removed
resource "time_sleep" "wait_for_cleanup" {
  # Sleep BEFORE destroying the operator to allow custom resources to clean up
  destroy_duration = "120s"

  depends_on = [
    helm_release.database_addons
  ]
}

# Database Addons Installation
# Install database addons as Terraform-managed Helm releases
# This ensures proper lifecycle management and clean teardown

locals {
  # Map of all available addons with their chart configurations
  addon_configs = {
    postgresql = {
      chart_name = "postgresql"
      version    = "1.0.1"
      repo       = "https://apecloud.github.io/helm-charts"
    }
    mysql = {
      chart_name = "mysql"
      version    = "1.0.1"
      repo       = "https://apecloud.github.io/helm-charts"
    }
    mongodb = {
      chart_name = "mongodb"
      version    = "1.0.1"
      repo       = "https://apecloud.github.io/helm-charts"
    }
    redis = {
      chart_name = "redis"
      version    = "1.0.1"
      repo       = "https://apecloud.github.io/helm-charts"
    }
    kafka = {
      chart_name = "kafka"
      version    = "1.0.1"
      repo       = "https://apecloud.github.io/helm-charts"
    }
  }

  # Filter only enabled addons
  enabled_addons = local.addon_configs
}

# Install each enabled addon as a separate Helm release
resource "helm_release" "database_addons" {
  for_each = local.enabled_addons

  name       = "kb-addon-${each.value.chart_name}"
  repository = each.value.repo
  chart      = each.value.chart_name
  version    = each.value.version
  namespace  = "kb-system"

  create_namespace = false # Namespace already created by kubeblocks release
  wait             = true
  wait_for_jobs    = true
  timeout          = 600 # 10 minutes
  max_history      = 10

  # Addons should not install CRDs - operator already installed them
  skip_crds = true

  atomic          = true # Rollback on failure
  cleanup_on_fail = true # Remove failed resources to allow retries

  # CRITICAL: Disable resource retention policy to allow clean deletion
  # This removes 'helm.sh/resource-policy: keep' annotation from ComponentDefinitions, ConfigMaps, etc.
  # Without this, resources are kept after Helm uninstall, blocking CRD deletion
  # Reference: https://kubeblocks.io/docs/preview/user_docs/references/install-addons
  values = [
    yamlencode({
      extra = {
        keepResource = false
      }
    })
  ]

  # Ensure operator is fully deployed before installing addons
  depends_on = [
    helm_release.kubeblocks,
    time_sleep.wait_for_kubeblocks
  ]

  lifecycle {
    prevent_destroy = true
  }
}
