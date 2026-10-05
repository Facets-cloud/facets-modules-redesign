# ╔═══════════════════════════════════════════════════════════╗
# ║ Module: clickhouse/k8s/1.0                                ║
# ║ Renders a ClickHouseInstallation (CHI) via a local helm  ║
# ║ chart so no plan-time CRD schema check is needed.        ║
# ║ Wires the ClickHouse Keeper input as the zookeeper node. ║
# ╚═══════════════════════════════════════════════════════════╝

locals {
  spec               = var.instance.spec
  cluster_name       = lookup(local.spec, "cluster_name", "default")
  namespace          = lookup(local.spec, "namespace", "clickhouse")
  clickhouse_version = lookup(local.spec, "clickhouse_version", "24.8")
  shards             = lookup(local.spec, "shards", 1)
  replicas           = lookup(local.spec, "replicas", 3)
  storage_size       = lookup(local.spec, "storage_size", "100Gi")
  storage_class      = lookup(local.spec, "storage_class", "premium-rwo")
  cluster_domain     = lookup(local.spec, "cluster_domain", "cluster.local")
  resources          = lookup(local.spec, "resources", {})
  cpu                = lookup(local.resources, "cpu", "1")
  memory             = lookup(local.resources, "memory", "2Gi")

  # *_json string fields → decoded structures (jsondecode pattern)
  users    = jsondecode(lookup(local.spec, "users_json", "[]"))
  settings = jsondecode(lookup(local.spec, "settings_json", "{}"))

  # ClickHouse Keeper coordination endpoint from the clickhouse_keeper input.
  keeper_attrs = coalesce(var.inputs.clickhouse_keeper.attributes, {})
  keeper_host  = lookup(local.keeper_attrs, "service_host", "")
  keeper_port  = lookup(local.keeper_attrs, "port", 2181)

  # Dedicated node-pool placement (optional input — read defensively).
  # node_selector: map of labels to pin the pods onto the pool's nodes.
  # taints: list of {key,value,effect} that we translate into tolerations so
  # the pods are allowed onto the tainted pool. When node_pool is unwired both
  # collapse to empty and no placement is rendered.
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

resource "helm_release" "clickhouse" {
  name             = local.cluster_name
  chart            = "${path.module}/chart"
  namespace        = local.namespace
  create_namespace = true
  wait             = true
  cleanup_on_fail  = true

  values = [
    yamlencode({
      clusterName   = local.cluster_name
      namespace     = local.namespace
      image         = "clickhouse/clickhouse-server:${local.clickhouse_version}"
      shards        = local.shards
      replicas      = local.replicas
      storageClass  = local.storage_class
      storageSize   = local.storage_size
      clusterDomain = local.cluster_domain
      resources = {
        cpu    = local.cpu
        memory = local.memory
      }
      zookeeper = {
        host = local.keeper_host
        port = local.keeper_port
      }
      users    = local.users
      settings = local.settings
      # Dedicated node-pool placement (empty when node_pool input is unwired).
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    })
  ]
}

# The operator (CRDs) and the keeper must exist before this CHI is applied.
# Both are declared inputs, so Facets deploys them first at the blueprint level.
