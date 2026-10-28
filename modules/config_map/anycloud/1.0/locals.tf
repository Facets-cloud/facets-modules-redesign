# Cloud-neutral: a ConfigMap is pure Kubernetes, so there is no aws/gcp branch here. The kubernetes
# provider is supplied by the kubernetes_cluster input; cloud_provider is read only for the output
# contract.
locals {
  spec = var.instance.spec

  # DEFENSIVE reads — Facets does not inject schema defaults into var.instance.spec, so a key the
  # blueprint never set is genuinely absent. lookup() for flat fields (RULE-015); try() only for the
  # nested per-entry read below.
  cloud_provider = try(var.inputs.kubernetes_cluster.attributes.cloud_provider, null)

  namespace = lookup(local.spec, "namespace", "default")
  immutable = lookup(local.spec, "immutable", false)

  # Namespace bootstrap gate. Both terms come from spec, never from a resource attribute, so `count`
  # stays resolvable at PLAN time (a count gated on a wired input's computed value fails with
  # "Invalid count argument" on a greenfield apply). Skipped for the default namespace, which always
  # exists.
  create_namespace = lookup(local.spec, "create_namespace", true) && local.namespace != "default"

  # The release name is per CONFIG_MAP INSTANCE, not per namespace: several ConfigMaps commonly share
  # one namespace, and a namespace-scoped name would make each of them try to create the SAME helm
  # release -> "cannot re-use a name that is still in use". 53 is helm's release-name limit, so long
  # names fall back to an md5 prefix.
  ns_release_raw  = "${local.resource_name}-ns"
  ns_release_name = length(local.ns_release_raw) > 53 ? substr(md5(local.ns_release_raw), 0, 20) : local.ns_release_raw
  data_spec       = lookup(local.spec, "data", {})
  labels_spec     = lookup(local.spec, "labels", {})
  annotations     = lookup(local.spec, "annotations", {})

  # spec.data is a map of ConfigMap key -> { content }. Flatten to the key -> string map the
  # kubernetes provider wants. The map KEY is the ConfigMap key, so it is also the filename when a
  # consumer mounts an entry with subPath.
  data = { for k, v in local.data_spec : k => try(v.content, "") }

  # Sorted + joined so the output stays stable across plans (a list would reorder).
  data_keys = join(",", sort(keys(local.data)))

  labels = merge(local.labels_spec, {
    "app.kubernetes.io/managed-by" = "facets"
    "app.kubernetes.io/name"       = local.resource_name
  })
}
