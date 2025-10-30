locals {
  spec         = var.instance.spec
  node_pools   = local.spec.node_pools
  advanced     = lookup(var.instance, "advanced", {})
  gke_advanced = lookup(local.advanced, "gke", {})
  labels       = local.spec.labels
  taints       = local.spec.taints

  gcp_taints = {
    "NoSchedule" : "NO_SCHEDULE",
    "PreferNoSchedule" : "PREFER_NO_SCHEDULE",
    "NoExecute" : "NO_EXECUTE"
  }

  processed_taints = [
    for taint in local.taints : {
      key    = taint.key
      value  = taint.value
      effect = lookup(local.gcp_taints, taint.effect, taint.effect)
    }
  ]
}

