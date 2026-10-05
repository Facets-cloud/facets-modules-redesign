# ╔═══════════════════════════════════════════════════════════╗
# ║ Module: clickhouse_keeper/k8s/1.0                         ║
# ║ Renders a ClickHouseKeeperInstallation (CHK) via a local ║
# ║ helm chart so no plan-time CRD schema check is needed.    ║
# ║ Ordering: depends on clickhouse_operator input (CRDs).   ║
# ╚═══════════════════════════════════════════════════════════╝

locals {
  spec           = var.instance.spec
  keeper_name    = lookup(local.spec, "keeper_name", "clickhouse-keeper")
  namespace      = lookup(local.spec, "namespace", "clickhouse")
  replicas       = lookup(local.spec, "replicas", 3)
  storage_size   = lookup(local.spec, "storage_size", "20Gi")
  storage_class  = lookup(local.spec, "storage_class", "premium-rwo")
  cluster_domain = lookup(local.spec, "cluster_domain", "cluster.local")
  resources      = lookup(local.spec, "resources", {})
  cpu            = lookup(local.resources, "cpu", "500m")
  memory         = lookup(local.resources, "memory", "512Mi")

  # Dedicated node-pool placement (optional input — read defensively).
  # node_selector: map of labels to pin the pods onto the pool's nodes.
  # taints: list of {key,value,effect} translated into tolerations so the pods
  # are allowed onto the tainted pool. Both collapse to empty when unwired.
  # The node_pool output's custom node_selector can arrive empty, but every
  # node in a GKE pool reliably carries cloud.google.com/gke-nodepool=<name>,
  # and the output always exposes node_pool_name — so we pin on that label.
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
}

resource "helm_release" "keeper" {
  name             = local.keeper_name
  chart            = "${path.module}/chart"
  namespace        = local.namespace
  create_namespace = true
  wait             = true
  cleanup_on_fail  = true

  values = [
    yamlencode({
      keeperName    = local.keeper_name
      namespace     = local.namespace
      replicas      = local.replicas
      image         = "clickhouse/clickhouse-keeper:24.8-alpine"
      storageClass  = local.storage_class
      storageSize   = local.storage_size
      clusterDomain = local.cluster_domain
      resources = {
        cpu    = local.cpu
        memory = local.memory
      }
      # Dedicated node-pool placement (empty when node_pool input is unwired).
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    })
  ]
}

# The operator (and its CRDs) must exist before this CHK CR is applied.
# Facets deploys the clickhouse_operator input resource first (it is a
# declared input dependency), so ordering is handled at the blueprint level.
