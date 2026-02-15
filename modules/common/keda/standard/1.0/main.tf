resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = local.chart_version
  cleanup_on_fail  = true
  namespace        = "keda"
  create_namespace = true
  wait             = false
  atomic           = false

  values = [
    <<VALUES
prometheus_id: ${local.prometheus_release_id}
resources:
  operator:
    limits:
      cpu: ${local.cpu_limit}
      memory: ${local.memory_limit}
    requests:
      cpu: ${local.cpu_request}
      memory: ${local.memory_request}
VALUES
    , yamlencode({
      tolerations  = local.tolerations
      nodeSelector = local.node_selectors
    })
    , yamlencode(local.custom_values)
  ]
}
