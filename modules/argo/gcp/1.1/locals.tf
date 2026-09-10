locals {
  spec       = lookup(var.instance, "spec", {})
  project_id = var.inputs.cloud_account.attributes.project_id

  # Node pool scheduling. node_pool is declared optional in facets.yaml, and the
  # Control Plane injects var.inputs with ONLY the wired keys - so an unwired
  # optional input is genuinely ABSENT, not null. lookup() on it fails at plan
  # with "Unsupported attribute ... var.inputs is object with N attributes", and
  # the optional() default in variables.tf does not help (it only applies when
  # Terraform itself builds the object). try() is the correct access.
  node_selector = try(var.inputs.node_pool.node_selector, {})
  tolerations   = try(var.inputs.node_pool.taints, [])

  # ArgoCD
  argocd_spec    = lookup(local.spec, "argocd", {})
  argocd_enabled = lookup(local.argocd_spec, "enabled", true)
  argocd_version = lookup(local.argocd_spec, "chart_version", "9.4.16")
  argocd_values  = lookup(local.argocd_spec, "custom_values", {})

  # Namespace every Argo component is released into. Previously hardcoded at
  # each use site; named here because the shim needs it for both the RBAC and
  # FACETS_ARGOCD_NAMESPACE.
  argocd_namespace = lookup(local.argocd_spec, "namespace", "argocd")

  # Argo Workflows
  workflows_spec    = lookup(local.spec, "workflows", {})
  workflows_enabled = lookup(local.workflows_spec, "enabled", true)
  workflows_version = lookup(local.workflows_spec, "chart_version", "1.0.6")
  workflows_values  = lookup(local.workflows_spec, "custom_values", {})

  # Argo Events
  events_spec    = lookup(local.spec, "events", {})
  events_enabled = lookup(local.events_spec, "enabled", true)
  events_version = lookup(local.events_spec, "chart_version", "2.4.21")
  events_values  = lookup(local.events_spec, "custom_values", {})

  # Argo Events often lives in its own namespace (the standalone helm/argo-events
  # resources in the live blueprints use "argo-events"), while this module has
  # historically co-located it with ArgoCD. Configurable, defaulting to the
  # co-located behaviour so 1.0 stacks don't move on upgrade. Whatever is set
  # here is what events_namespace publishes, so consumers follow the truth.
  events_namespace = lookup(local.events_spec, "namespace", local.argocd_namespace)

  # Argo Rollouts
  rollouts_spec    = lookup(local.spec, "rollouts", {})
  rollouts_enabled = lookup(local.rollouts_spec, "enabled", true)
  rollouts_version = lookup(local.rollouts_spec, "chart_version", "2.40.8")
  rollouts_values  = lookup(local.rollouts_spec, "custom_values", {})

  # Workflows SA roles
  workflows_sa_roles = lookup(local.spec, "workflows_sa_roles", {
    artifact_registry_reader = { role = "roles/artifactregistry.reader" }
    artifact_registry_writer = { role = "roles/artifactregistry.writer" }
  })

  # SA naming
  workflows_sa_id   = module.gsa_name.name
  workflows_sa_name = "workflows-sa"

  # Whether this module creates the Workflows k8s ServiceAccount via the Helm
  # chart (default true). Set false when the SA is managed externally (git-synced)
  # — the module then creates only the GCP SA + WI binding.
  workflows_create_sa = lookup(local.workflows_spec, "create_service_account", true)

  # Namespace of the k8s ServiceAccount the Workflows GCP SA is WI-bound to.
  # Defaults to the argo-workflows Helm release namespace (argocd); set to the
  # namespace where the build pods run (e.g. workflows) when the SA lives there.
  workflows_sa_namespace = lookup(local.workflows_spec, "service_account_namespace", "argocd")
}
