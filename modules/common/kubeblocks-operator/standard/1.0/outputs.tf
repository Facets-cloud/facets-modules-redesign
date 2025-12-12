locals {
  output_attributes = {
    namespace      = kubernetes_namespace.kubeblocks.metadata[0].name
    version        = helm_release.kubeblocks.version
    chart_version  = helm_release.kubeblocks.version
    release_name   = helm_release.kubeblocks.name
    release_id     = helm_release.kubeblocks.id
  }

  output_interfaces = {}
}