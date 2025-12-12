locals {
  spec = var.instance.spec
  node_pools = {
    for key, value in local.spec.node_pools :
    "${var.instance_name}-${key}" => value
  }
  advanced     = lookup(var.instance, "advanced", {})
  gke_advanced = lookup(local.advanced, "gke", {})
  labels       = lookup(local.spec, "labels", {})
  taints       = lookup(local.spec, "taints", [])

  gcp_taints = {
    "NoSchedule" : "NO_SCHEDULE",
    "PreferNoSchedule" : "PREFER_NO_SCHEDULE",
    "NoExecute" : "NO_EXECUTE"
  }
}

