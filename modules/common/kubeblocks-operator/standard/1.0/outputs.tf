locals {
  output_attributes = {
    namespace      = kubernetes_namespace.kubeblocks.metadata[0].name
    version        = helm_release.kubeblocks.version
    chart_version  = helm_release.kubeblocks.version
    release_name   = helm_release.kubeblocks.name
    release_status = helm_release.kubeblocks.status
    crd_dependency = local.crd_release_id
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
# Output the interfaces for use by dependent modules
output "output_interfaces" {
  description = "Interface outputs for dependency management and status tracking"
  value       = local.output_interfaces
}