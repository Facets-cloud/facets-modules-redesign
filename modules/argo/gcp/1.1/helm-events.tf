# ── Argo Events ─────────────────────────────────────────────────────────────

locals {
  events_defaults = {
    controller = {
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    }
  }

  # merge() is SHALLOW, and custom_values collides with the defaults above on
  # `controller`. Verified: custom_values {controller:{replicas:3}} against
  # {controller:{nodeSelector,tolerations}} yields ONLY {controller:{replicas:3}}
  # - the node placement is silently dropped and the pods schedule anywhere.
  # So merge one level into each top-level key. Both ternary arms emit JSON text
  # so the expression stays single-typed across mixed values (maps, strings,
  # numbers, lists); decode once at the end. custom_values wins on conflicts.
  events_sources = [local.events_defaults, local.events_values]

  events_merged = jsondecode(join("", [
    "{",
    join(",", [
      for k, v in merge(local.events_sources...) :
      "${jsonencode(k)}:${
        can(keys(v))
        ? jsonencode(merge([
          for src in local.events_sources : lookup(src, k, {})
          if can(keys(lookup(src, k, {})))
        ]...))
        : jsonencode(v)
      }"
    ]),
    "}",
  ]))
}

resource "helm_release" "events" {
  count      = local.events_enabled ? 1 : 0
  name       = "argo-events"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-events"
  version    = local.events_version
  namespace  = local.events_namespace

  create_namespace = true
  wait             = true
  timeout          = 300

  values = [yamlencode(local.events_merged)]
}
