locals {
  output_interfaces = {}
  output_attributes = {
    # The claims are namespaced; list the managed set as "<namespace>/<name>" keys.
    resource_name = join(",", sort(keys(kubernetes_persistent_volume_claim.pvc)))
  }
}
