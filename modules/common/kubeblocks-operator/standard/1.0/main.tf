# CRDs are installed by the separate kubeblocks-crd module
# This module depends on that module's release_id to ensure proper ordering
locals {
  crd_input      = var.inputs.kubeblocks_crd
  crd_interfaces = lookup(local.crd_input, "interfaces", {})
  crd_output     = lookup(local.crd_interfaces, "output", {})
  crd_release_id = lookup(local.crd_output, "release_id", "")
  crd_ready      = lookup(local.crd_output, "ready", "false")
}

# Kubernetes Namespace for KubeBlocks
resource "kubernetes_namespace" "kubeblocks" {
  metadata {
    name = "kb-system" # Default namespace name

    labels = merge(
      {
        "app.kubernetes.io/name"       = "kubeblocks"
        "app.kubernetes.io/instance"   = var.instance_name
        "app.kubernetes.io/version"    = var.instance.spec.version
        "app.kubernetes.io/managed-by" = "terraform"
      },
      var.environment.cloud_tags
    )
    annotations = {
      "kubeblocks.io/crd-dependency" = local.crd_release_id
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels
    ]
  }

  # Wait for namespace deletion to complete
  # This ensures Terraform waits for all resources to be cleaned up
  timeouts {
    delete = "10m"
  }
}

# KubeBlocks Helm Release
# CRDs are automatically installed via kubernetes_manifest resources above
resource "helm_release" "kubeblocks" {
  name       = "kubeblocks"
  repository = "https://apecloud.github.io/helm-charts"
  chart      = "kubeblocks"
  version    = var.instance.spec.version
  namespace  = kubernetes_namespace.kubeblocks.metadata[0].name

  create_namespace = false
  wait             = false # Disable wait to prevent destroy hang issues
  wait_for_jobs    = false # Disable wait_for_jobs to prevent timeout issues
  timeout          = 600
  max_history      = 10

  # Skip CRDs - they're already installed via kubernetes_manifest resources
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
          enabled = true # Enable data protection features by default
          tolerations = [
            {
              key      = "kubernetes.azure.com/scalesetpriority"
              operator = "Equal"
              value    = "spot"
              effect   = "NoSchedule"
            },
            {
              # allow running on the mongodb-tainted node
              key      = "mongodb"
              operator = "Equal"
              value    = "true"
              effect   = "NoSchedule"
            }
          ]
        }
        featureGates = {
          inPlacePodVerticalScaling = {
            enabled = lookup(lookup(var.instance.spec, "feature_gates", {}), "in_place_pod_vertical_scaling", false)
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
        tolerations = [
          {
            key      = "kubernetes.azure.com/scalesetpriority"
            operator = "Equal"
            value    = "spot"
            effect   = "NoSchedule"
          },
          {
            # allow running on the mongodb-tainted node
            key      = "mongodb"
            operator = "Equal"
            value    = "true"
            effect   = "NoSchedule"
          }
        ]
      },
    ))
  ]

  # Ensure namespace and CRDs exist before installing the operator
  depends_on = [
    kubernetes_namespace.kubeblocks
  ]
}
resource "time_sleep" "wait_for_kubeblocks" {
  create_duration = "120s" # Wait 2 minutes
  depends_on      = [helm_release.kubeblocks]
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
  enabled_addons = {
    for name, config in local.addon_configs :
    name => config
    if lookup(lookup(var.instance.spec, "database_addons", {}), name, false) == true
  }
}

# Install each enabled addon as a separate Helm release
resource "helm_release" "database_addons" {
  for_each = local.enabled_addons

  name       = "kb-addon-${each.value.chart_name}"
  repository = each.value.repo
  chart      = each.value.chart_name
  version    = each.value.version
  namespace  = kubernetes_namespace.kubeblocks.metadata[0].name

  create_namespace = false
  wait             = true
  wait_for_jobs    = true
  timeout          = 600 # 10 minutes
  max_history      = 10

  # Addons should not install CRDs - operator already installed them
  skip_crds = true

  atomic          = true # Rollback on failure
  cleanup_on_fail = true # Remove failed resources to allow retries

  # Ensure operator is fully deployed before installing addons
  depends_on = [
    helm_release.kubeblocks,
    time_sleep.wait_for_kubeblocks
  ]
}
