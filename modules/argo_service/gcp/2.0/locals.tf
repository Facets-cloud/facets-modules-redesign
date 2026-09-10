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

  # environment.unique_name is "<project>-<envName>" by construction, so the
  # project name is the prefix with the environment suffix trimmed off. This is
  # the same derivation service/argo/2.1 uses.
  project_name = trimsuffix(var.environment.unique_name, "-${var.environment.name}")

  # ---------------------------------------------------------------------------
  # facets-argo-shim contract
  #
  # The shim replaces `helm` inside argocd-repo-server and resolves
  # ${facets:...} refs in the rendered manifest stream. Per-Application
  # annotations are its ONLY coordinate source - without project/environment
  # any render containing a ref fails CLOSED. On an ApplicationSet these must
  # sit on the Application TEMPLATE metadata so they propagate to the
  # generated Application, which is what the shim actually lists and reads.
  #
  # The three resource-* annotations are all-or-nothing and opt into the
  # consumed-references callback (see facets_references below).
  # ---------------------------------------------------------------------------

  facets_annotations = {
    "facets.cloud/project"          = local.project_name
    "facets.cloud/environment"      = var.environment.name
    "facets.cloud/resource-type"    = "argo_service"
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
  # both the chart values and the RBAC grant are in place, and the precondition
  # in main.tf gates on it.
  #
  # Gated on evidence this service actually uses refs, so a ref-free chart
  # still deploys to a shim-less cluster: either a previous render reported
  # consumed expressions, or a ${facets:...} literal appears in the values path
  # or the inline helm values.
  # ---------------------------------------------------------------------------

  shim_enabled = try(var.inputs.argo_stack.attributes.shim_enabled, false)

  uses_facets_refs = anytrue([
    length(local.env_reference_expressions) > 0,
    can(regex("\\$\\{facets:", local.chart.values_path)),
    can(regex("\\$\\{facets:", jsonencode(lookup(local.spec, "helm_values", {})))),
  ])

  # ---------------------------------------------------------------------------
  # Sync policy
  # ---------------------------------------------------------------------------

  sync_policy = lookup(local.spec, "sync_policy", {})

  auto_prune         = lookup(local.sync_policy, "auto_prune", false)
  self_heal          = lookup(local.sync_policy, "self_heal", false)
  automated          = lookup(local.sync_policy, "automated", true)
  preserve_on_delete = lookup(local.sync_policy, "preserve_on_delete", true)
  retry_limit        = lookup(lookup(local.sync_policy, "retry", {}), "limit", 5)

  sync_options = concat(
    ["CreateNamespace=true"],
    local.auto_prune ? ["PrunePropagationPolicy=foreground"] : [],
  )

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
  # Helm values: user-supplied values plus the references digest.
  # ---------------------------------------------------------------------------

  helm_values_object = merge(
    lookup(local.spec, "helm_values", {}),
    local.reference_values_object,
  )

  application_helm = merge(
    {
      releaseName = local.release_name
      valueFiles  = [local.chart.values_path]
    },
    length(local.helm_values_object) > 0 ? {
      valuesObject = local.helm_values_object
    } : {},
  )

  # ---------------------------------------------------------------------------
  # ApplicationSet
  #
  # A single-element list generator: one Application per environment, named for
  # the blueprint resource. The generator element carries the cluster identity
  # so it stays available to chart templates via {{cluster}}.
  # ---------------------------------------------------------------------------

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
        spec = {
          project = lookup(local.spec, "argocd_project", "default")
          source = {
            repoURL        = local.chart.repo_url
            targetRevision = lookup(local.chart, "revision", "develop")
            path           = local.chart.path
            helm           = local.application_helm
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = local.namespace
          }
          syncPolicy = local.application_sync_policy
        }
      }
      syncPolicy = {
        preserveResourcesOnDeletion = local.preserve_on_delete
      }
    }
  }
}
