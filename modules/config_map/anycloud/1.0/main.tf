# ── Namespace bootstrap ─────────────────────────────────────────────────────────────────────────
# A raw kubernetes_config_map_v1 cannot create its own namespace, so a ConfigMap applied before the
# namespace exists fails with `namespaces "<ns>" not found`. That forced consumers to hand-order
# releases (namespace -> ConfigMap -> service), and a ConfigMap that failed left services mounting an
# empty configMap name.
#
# This release fixes the ordering WITHOUT taking ownership of the namespace. helm_release with
# create_namespace = true creates the namespace OUT OF BAND: it is never part of the release manifest,
# so it carries no helm ownership metadata and is NOT deleted when the release is uninstalled
# (create-and-abandon). Consequences that matter:
#   * removing/disabling this ConfigMap can never delete a namespace it shares with other workloads;
#   * any number of releases may target the same namespace — the first creates it, the rest no-op;
#   * a namespace created this way stays adoptable by other create_namespace consumers, in any order.
# The chart renders NO Kubernetes objects; the release exists purely to trigger create_namespace.
#
# Deliberately NOT used here: templating a Namespace into a manifest (helm then owns it and deletes it
# on uninstall) or kubernetes_namespace (Terraform owns it and deletes it on disable).
resource "helm_release" "namespace" {
  count = local.create_namespace ? 1 : 0

  name             = local.ns_release_name
  chart            = "${path.module}/charts/namespace"
  namespace        = local.namespace
  create_namespace = true
}

# The ConfigMap itself. Created directly with the kubernetes provider rather than wrapped in a
# helm_release: a helm-managed ConfigMap would have to adopt any pre-existing object of the same name,
# and helm ownership metadata would make the ConfigMap unmanageable outside the release.
resource "kubernetes_config_map_v1" "this" {
  # The namespace must exist before the ConfigMap is created; without this the ConfigMap races the
  # bootstrap release above (no attribute of it is referenced anywhere in this resource).
  depends_on = [helm_release.namespace]

  metadata {
    name        = local.resource_name
    namespace   = local.namespace
    labels      = local.labels
    annotations = local.annotations
  }

  data      = local.data
  immutable = local.immutable
}
