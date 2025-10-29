locals {
  output_attributes = {
    namespace      = kubernetes_namespace.kubeblocks.metadata[0].name
    version        = helm_release.kubeblocks.version
    chart_version  = helm_release.kubeblocks.version
    release_name   = helm_release.kubeblocks.name
    release_status = helm_release.kubeblocks.status
    crds_installed = length(kubernetes_manifest.kubeblocks_crds)
  }

  output_interfaces = {
    output = {
      # Helm release ID for dependency management (known after apply)
      release_id     = helm_release.kubeblocks.id
      release_status = helm_release.kubeblocks.status

      # Readiness indicator - use status directly instead of boolean expression
      ready = helm_release.kubeblocks.status

      # Dependency key for other modules to wait on
      dependency_id = "${helm_release.kubeblocks.id}-${kubernetes_namespace.kubeblocks.metadata[0].uid}"
    }
  }
}

# Expose outputs for external module consumption
output "output_attributes" {
  description = "Attribute outputs for KubeBlocks operator information"
  value       = local.output_attributes
}

output "output_interfaces" {
  description = "Interface outputs for dependency management and status tracking"
  value       = local.output_interfaces
}