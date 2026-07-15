# ╔═══════════════════════════════════════════════════════════╗
# ║ Module: clickhouse_operator/k8s/1.0                       ║
# ║ Installs the Altinity ClickHouse operator + CRDs via Helm ║
# ╚═══════════════════════════════════════════════════════════╝

locals {
  spec      = var.instance.spec
  namespace = lookup(local.spec, "namespace", "clickhouse")
  resources = lookup(local.spec, "resources", {})
  cpu       = lookup(local.resources, "cpu", "100m")
  memory    = lookup(local.resources, "memory", "256Mi")

  # Dedicated node-pool placement (optional input — read defensively).
  # The node_pool output's custom node_selector can arrive empty, but every node
  # in a GKE pool reliably carries cloud.google.com/gke-nodepool=<name>, and the
  # output always exposes node_pool_name — so we pin on that label.
  node_pool_name = try(var.inputs.node_pool.attributes.node_pool_name, "")
  node_selector = merge(
    try(var.inputs.node_pool.attributes.node_selector, {}),
    local.node_pool_name != "" ? { "cloud.google.com/gke-nodepool" = local.node_pool_name } : {}
  )
  # GKE reports taint effect as NO_SCHEDULE/PREFER_NO_SCHEDULE/NO_EXECUTE;
  # k8s tolerations require the camelCase form. Normalise (passthrough if already correct).
  effect_map = {
    NO_SCHEDULE        = "NoSchedule"
    PREFER_NO_SCHEDULE = "PreferNoSchedule"
    NO_EXECUTE         = "NoExecute"
    NoSchedule         = "NoSchedule"
    PreferNoSchedule   = "PreferNoSchedule"
    NoExecute          = "NoExecute"
  }
  node_taints = try(var.inputs.node_pool.attributes.taints, [])
  tolerations = [
    for t in local.node_taints : {
      key      = t.key
      value    = t.value
      effect   = lookup(local.effect_map, t.effect, t.effect)
      operator = "Equal"
    }
  ]

  # Only emit placement keys when a node_pool is wired, so the chart defaults
  # (unpinned) are preserved otherwise. Both the operator Deployment (top-level
  # nodeSelector/tolerations) and the CRD-install Job (crdHook.*) are pinned —
  # the crdHook is a pre-install hook and would otherwise fail to schedule on
  # the tainted/at-capacity default nodes and hang the release.
  placement = merge(
    length(local.node_selector) > 0 ? { nodeSelector = local.node_selector } : {},
    length(local.tolerations) > 0 ? { tolerations = local.tolerations } : {},
  )
  crd_hook = length(local.placement) > 0 ? { crdHook = local.placement } : {}
}

resource "helm_release" "operator" {
  name             = "clickhouse-operator"
  repository       = "https://docs.altinity.com/clickhouse-operator/"
  chart            = "altinity-clickhouse-operator"
  version          = lookup(local.spec, "operator_version", "0.24.0")
  namespace        = local.namespace
  create_namespace = true
  wait             = true
  cleanup_on_fail  = true

  values = [
    yamlencode(merge({
      operator = {
        resources = {
          requests = {
            cpu    = local.cpu
            memory = local.memory
          }
          limits = {
            cpu    = local.cpu
            memory = local.memory
          }
        }
      }
      },
      # Top-level nodeSelector/tolerations pin the operator Deployment pod.
      local.placement,
      # crdHook.nodeSelector/tolerations pin the CRD-install Job.
      local.crd_hook,
    ))
  ]
}
