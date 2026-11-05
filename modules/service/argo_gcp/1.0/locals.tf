locals {
  spec = var.instance.spec

  # ---------------------------------------------------------------------------
  # Identity
  # ---------------------------------------------------------------------------

  service_name = var.instance_name
  namespace    = local.spec.namespace

  chart        = local.spec.chart
  release_name = trimspace(lookup(local.chart, "release_name", "")) != "" ? local.chart.release_name : local.service_name

  # ArgoCD's own namespace comes from the argo stack rather than a hardcoded
  # "argocd", so a stack installed elsewhere still works.
  argocd_namespace = coalesce(
    try(var.inputs.argo_stack.attributes.argocd_namespace, null),
    "argocd",
  )

  project_id = try(var.inputs.cloud_account.attributes.project_id, "")

  # environment.unique_name is "<project>-<envName>" by construction, so the
  # project name is the prefix with the environment suffix trimmed off.
  project_name = trimsuffix(var.environment.unique_name, "-${var.environment.name}")

  # ---------------------------------------------------------------------------
  # facets-argo-shim contract
  #
  # Per-Application annotations are the shim's ONLY coordinate source - without
  # project/environment any render containing a ${facets:...} ref fails CLOSED.
  # On an ApplicationSet these must sit on the Application TEMPLATE metadata so
  # they propagate to the generated Application, which is what the shim lists.
  #
  # The three resource-* annotations are all-or-nothing and opt into the
  # consumed-references callback (see facets_references below).
  # ---------------------------------------------------------------------------

  facets_annotations = {
    "facets.cloud/project"          = local.project_name
    "facets.cloud/environment"      = var.environment.name
    "facets.cloud/resource-type"    = "service"
    "facets.cloud/resource-name"    = var.instance_name
    "facets.cloud/references-field" = "facets_references"
  }

  # User annotations first, so the facets.cloud/* keys always win.
  application_annotations = merge(
    lookup(local.spec, "annotations", {}),
    local.facets_annotations,
  )

  # ---------------------------------------------------------------------------
  # Consumed-references write-back loop
  #
  # The shim resolves refs at RENDER time, so a Facets release that changes a
  # referenced value would never reach an already-deployed Application - Argo
  # only re-syncs when the CR (or the Git content it points at) changes. The
  # shim's callback reports the expressions each render consumed into
  # spec.facets_references.<env>.expressions; the CP resolves them before this
  # module runs, and folding a digest of the resolved values into the CR makes
  # any change to them mutate the CR -> Argo re-renders on its own watch.
  #
  # Digest only, deliberately: resolved values may include sensitive material
  # and must not land in the Application CR (which Argo stores, diffs, and
  # renders in its UI). The sha1 changes exactly when a referenced value does.
  # ---------------------------------------------------------------------------

  env_reference_expressions = try(
    local.spec.facets_references[var.environment.name].expressions,
    [],
  )

  reference_values_object = length(local.env_reference_expressions) > 0 ? {
    facets_references_hash = sha1(jsonencode(local.env_reference_expressions))
  } : {}

  # ---------------------------------------------------------------------------
  # Shim gate
  #
  # The shim lives in argocd-repo-server, so Terraform can't observe whether a
  # render will succeed - a shim-less cluster applies green and then fails
  # inside ArgoCD at render time. argo/gcp >= 1.1 publishes shim_enabled once
  # both the chart values and the RBAC grant are in place.
  #
  # Gated on evidence this service actually uses refs, so a ref-free chart
  # still deploys to a shim-less cluster.
  # ---------------------------------------------------------------------------

  shim_enabled = try(var.inputs.argo_stack.attributes.shim_enabled, false)

  uses_facets_refs = anytrue([
    length(local.env_reference_expressions) > 0,
    can(regex("\\$\\{facets:", lookup(local.chart, "values_path", ""))),
    can(regex("\\$\\{facets:", jsonencode(lookup(local.spec, "helm_values", {})))),
  ])

  # ---------------------------------------------------------------------------
  # Sync policy
  # ---------------------------------------------------------------------------

  sync_policy = lookup(local.spec, "sync_policy", {})
  advanced    = lookup(local.spec, "advanced", {})

  auto_prune         = lookup(local.sync_policy, "auto_prune", false)
  self_heal          = lookup(local.sync_policy, "self_heal", false)
  automated          = lookup(local.sync_policy, "automated", true)
  preserve_on_delete = lookup(local.sync_policy, "preserve_on_delete", true)
  retry_limit        = lookup(lookup(local.sync_policy, "retry", {}), "limit", 5)

  sync_options = distinct(concat(
    ["CreateNamespace=true"],
    local.auto_prune ? ["PrunePropagationPolicy=foreground"] : [],
    lookup(local.advanced, "sync_options", []),
  ))

  # syncPolicy.automated is absent (not false) when disabled - Argo treats the
  # key's presence as "automated", so it has to be omitted entirely.
  application_sync_policy = merge(
    { syncOptions = local.sync_options },
    local.automated ? {
      automated = {
        prune    = local.auto_prune
        selfHeal = local.self_heal
      }
    } : {},
    local.retry_limit > 0 ? {
      retry = { limit = local.retry_limit }
    } : {},
  )

  # ---------------------------------------------------------------------------
  # Helm values: user values + the artifact image + Workload Identity
  # annotations + the references digest.
  #
  # 2.x guessed a chart's internal values root from a hardcoded table of
  # CoinSwitch chart names (chart_default_values_roots). That coupled a general
  # flavor to specific charts and silently produced the wrong path for anything
  # not in the table. 3.0 takes values_root explicitly per service account.
  # ---------------------------------------------------------------------------

  release      = lookup(local.spec, "release", {})
  image        = trimspace(lookup(local.release, "image", ""))
  image_path   = trimspace(lookup(local.release, "image_values_path", ""))
  inject_image = local.image != "" && local.image_path != ""

  # "myapp.image" -> { myapp = { image = "<uri>" } }
  #
  # Terraform has no fold and cannot self-reference a local mid-comprehension,
  # and a nested ternary fails with "Inconsistent conditional result types" (the
  # innermost value is a string, every wrapper is an object). Building the JSON
  # text directly sidesteps both: wrap the value in one `{"seg":` per segment,
  # then close with the matching braces, and decode once.
  image_path_parts = local.inject_image ? split(".", local.image_path) : []

  # Both branches are JSON *text* so the conditional stays one type; decode once
  # outside it. (Decoding inside would make the true branch a string when the
  # path is empty, against an object false branch - "Inconsistent conditional
  # result types".)
  image_values = jsondecode(local.inject_image ? join("", concat(
    [for seg in local.image_path_parts : "{${jsonencode(seg)}:"],
    [jsonencode(local.image)],
    [for _ in local.image_path_parts : "}"],
  )) : "{}")

  wi_spec     = lookup(local.spec, "workload_identity", {})
  wi_accounts = { for k, v in lookup(local.wi_spec, "service_accounts", {}) : k => v if lookup(v, "enabled", true) }

  # GCP service accounts are only created for entries that ask for GCP roles;
  # an aws-only entry needs no GCP identity.
  wi_gcp_accounts = { for k, v in local.wi_accounts : k => v if length(lookup(v, "roles", {})) > 0 }

  # Flattened (account, role) pairs for the IAM bindings.
  wi_role_bindings = merge([
    for k, v in local.wi_gcp_accounts : {
      for rk, rv in lookup(v, "roles", {}) : "${k}.${rk}" => {
        account = k
        role    = rv.role
      }
    }
  ]...)

  # Values root each account's annotation is injected under. Explicit, with the
  # map key as the fallback.
  wi_values_root = {
    for k, v in local.wi_accounts :
    k => trimspace(lookup(v, "values_root", "")) != "" ? v.values_root : k
  }

  # serviceaccount annotations merged into the chart values, per account.
  wi_values = {
    for k, v in local.wi_accounts :
    local.wi_values_root[k] => {
      serviceaccount = {
        annotations = merge(
          contains(keys(local.wi_gcp_accounts), k) ? {
            "iam.gke.io/gcp-service-account" = "${module.wi_name[k].name}@${local.project_id}.iam.gserviceaccount.com"
          } : {},
          lookup(lookup(v, "aws", {}), "enabled", false) ? {
            "eks.amazonaws.com/role-arn" = lookup(lookup(v, "aws", {}), "role_arn", "")
            "eks.amazonaws.com/region"   = lookup(lookup(v, "aws", {}), "region", "ap-south-1")
          } : {},
        )
      }
    }
  }

  # Sources that contribute chart values, lowest precedence first.
  helm_values_sources = [
    lookup(local.spec, "helm_values", {}),
    local.image_values,
    local.wi_values,
    local.reference_values_object,
  ]

  # A plain merge() here is SHALLOW, and these sources routinely write under the
  # same top-level chart key. Verified against the cluster: helm_values
  # {image:{tag:""}} plus image_values_path "image.repository" produced only
  # {image:{repository:...}} in the Application - merge() replaced the whole
  # `image` map and silently dropped `tag`, rendering an invalid
  # "nginx:1.29-alpine:1.27-alpine". wi_values has the same exposure: its
  # <values_root>.serviceaccount.annotations would clobber a user's own
  # helm_values at that root.
  #
  # So union the top-level keys, then for any key that every contributing source
  # sets as a map, merge those maps instead of overwriting. Both branches emit
  # JSON *text* so the conditional stays a single type: values here are mixed
  # (maps, strings, numbers, lists, null) and a map/string ternary fails with
  # "Inconsistent conditional result types". Decode once at the end.
  #
  # Merging is one level deep - `a.b` still replaces wholesale - which covers
  # every shape these sources produce (image.*,
  # <root>.serviceaccount.annotations, facets_references_hash).
  helm_values_flat = merge(local.helm_values_sources...)

  helm_values_object = jsondecode(join("", [
    "{",
    join(",", [
      for k, v in local.helm_values_flat :
      "${jsonencode(k)}:${
        can(keys(v))
        ? jsonencode(merge([
          for src in local.helm_values_sources : lookup(src, k, {})
          if can(keys(lookup(src, k, {})))
        ]...))
        : jsonencode(v)
      }"
    ]),
    "}",
  ]))

  values_path = trimspace(lookup(local.chart, "values_path", ""))

  application_helm = merge(
    { releaseName = local.release_name },
    local.values_path != "" ? { valueFiles = [local.values_path] } : {},
    length(local.helm_values_object) > 0 ? { valuesObject = local.helm_values_object } : {},
  )

  # ---------------------------------------------------------------------------
  # ApplicationSet
  # ---------------------------------------------------------------------------

  application_template_spec = merge(
    {
      project = lookup(local.spec, "argocd_project", "default")
      source = {
        repoURL        = local.chart.repo_url
        targetRevision = lookup(local.chart, "revision", "HEAD")
        path           = local.chart.path
        helm           = local.application_helm
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = local.namespace
      }
      syncPolicy = local.application_sync_policy
    },
    length(lookup(local.advanced, "ignore_differences", [])) > 0 ? {
      ignoreDifferences = local.advanced.ignore_differences
    } : {},
    # Applied last so it can override anything above.
    lookup(local.advanced, "application_overrides", {}),
  )

  applicationset = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata = {
      name      = local.service_name
      namespace = local.argocd_namespace
    }
    spec = {
      generators = [{
        list = {
          elements = [{
            cluster = var.environment.unique_name
            url     = "https://kubernetes.default.svc"
          }]
        }
      }]
      template = {
        metadata = {
          name        = local.service_name
          annotations = local.application_annotations
        }
        spec = local.application_template_spec
      }
      syncPolicy = {
        preserveResourcesOnDeletion = local.preserve_on_delete
      }
    }
  }

  # ---------------------------------------------------------------------------
  # DNS
  # ---------------------------------------------------------------------------

  dns             = lookup(local.spec, "dns_record", {})
  dns_enabled     = lookup(local.dns, "enabled", false)
  dns_targets     = local.dns_enabled ? [for t in split(",", lookup(local.dns, "target", "")) : trimspace(t) if trimspace(t) != ""] : []
  dns_is_ip       = length(local.dns_targets) > 0 ? can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", local.dns_targets[0])) : false
  dns_record_type = local.dns_is_ip ? "A" : "CNAME"
  # CNAME rrdatas must be fully qualified.
  dns_rrdatas = local.dns_is_ip ? local.dns_targets : [for t in local.dns_targets : endswith(t, ".") ? t : "${t}."]
}
