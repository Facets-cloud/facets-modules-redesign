# ── facets-argo-shim ────────────────────────────────────────────────────────
#
# Installs the facets-argo-shim into argocd-repo-server so ${facets:...}
# references inside charts deployed by ArgoCD resolve against the Facets
# control plane. See https://github.com/Facets-cloud/facets-argo-shim.
#
# This lives in the argo module, not a separate one, deliberately: the shim is
# configured through the argo-cd chart's own repoServer.* values, so it must be
# owned by the same helm_release that owns repo-server. A separate module
# patching the Deployment out-of-band would be reverted the next time this
# release applied (two owners of one resource).
#
# The shim's install shape (initContainers + a shared /custom-tools emptyDir +
# a subPath mount shadowing /usr/local/bin/helm) comes from the repo's README
# "Install — Helm chart" recipe. Two path spaces are involved and are easy to
# conflate:
#   /opt/facets/...    where the shim image BAKES its artifacts
#   /custom-tools/...  where the initContainer COPIES them, and where
#                      helm-shim.sh's own defaults expect them at runtime
# Copy FROM /opt/facets INTO /custom-tools, never the reverse — /custom-tools
# is the initContainer's mount point, so baking there would let the volume
# shadow the baked files before the copy ran.

locals {
  shim_spec    = lookup(local.argocd_spec, "facets_shim", {})
  shim_enabled = local.argocd_enabled && lookup(local.shim_spec, "enabled", false)

  shim_image   = lookup(local.shim_spec, "image", "docker.io/facetscloud/facets-argo-shim:v0.13.1")
  shim_version = local.shim_enabled ? reverse(split(":", local.shim_image))[0] : ""

  # The initContainer that copies real helm must run the SAME argocd image as
  # the release, so the shimmed helm is version-exact by construction rather
  # than pinned to a guess. Falls back to the upstream default when not set.
  shim_argocd_image = lookup(local.shim_spec, "argocd_image", "quay.io/argoproj/argocd:v3.3.5")

  # Credentials the shim authenticates to the control plane with. The module
  # CREATES the Kubernetes Secret from these (see below) - the user only
  # supplies a username and a token, ideally as a project-secret expression.
  #
  # Why the token cannot come from the platform: the resolver talks to
  # /cc-ui/v1/... endpoints, which use basic auth with a Facets USER identity.
  # The TF_VAR_cc_auth_token the platform injects is an internal deployer token
  # for /cc/v1/... and returns 401 on every /cc-ui/v1 endpoint (verified). There
  # is also no API to mint a personal token - the CP UI shows it once. So a
  # scoped service user has to be created out of band; everything else here is
  # module-owned.
  shim_cp_username = trimspace(lookup(local.shim_spec, "cp_username", ""))
  shim_cp_token    = trimspace(lookup(local.shim_spec, "cp_token", ""))

  # Control-plane base URL, from the injected TF_VAR_cc_host (see the
  # data.external below). "https://" alone means the var was absent.
  shim_cp_url = local.shim_enabled ? data.external.cp_host[0].result.url : ""

  # Name of the Secret this module creates in the ArgoCD namespace.
  shim_credentials_secret = lookup(local.shim_spec, "credentials_secret", "facets-cp-credentials")

  # RBAC object name. Includes instance_name so two argo resources in the SAME
  # namespace don't fight over one Role/RoleBinding — the objects are
  # namespace-scoped, so a bare constant would make them collide and each
  # release would overwrite the other's. Overridable for a pre-existing grant.
  shim_rbac_name = lookup(
    local.shim_spec,
    "rbac_name",
    "facets-shim-app-reader-${var.instance_name}",
  )

  # On the argo-helm chart the repo-server ServiceAccount is
  # "<release>-argocd-repo-server"; the RoleBinding subject must match.
  shim_repo_server_sa = lookup(
    local.shim_spec,
    "repo_server_service_account",
    "argo-cd-argocd-repo-server",
  )

  # repoServer.* values merged into the argo-cd release. Only applied when the
  # shim is enabled (see argocd_repo_server below), so a disabled shim
  # contributes nothing to the values at all.
  shim_repo_server_values = {
    # Required: per-Application annotations are the ONLY coordinate source, and
    # reading them needs repo-server's own SA token. Upstream installs ship
    # this false because repo-server normally needs no API access.
    automountServiceAccountToken = true

    initContainers = [
      {
        name    = "copy-helm-real"
        image   = local.shim_argocd_image
        command = ["sh", "-c", "cp /usr/local/bin/helm /custom-tools/helm-real"]
        volumeMounts = [
          { name = "custom-tools", mountPath = "/custom-tools" },
        ]
      },
      {
        name  = "copy-facets-tools"
        image = local.shim_image
        command = ["sh", "-c", join(" && ", [
          "cp /opt/facets/facets-resolver /custom-tools/",
          "cp /opt/facets/helm-shim.sh /custom-tools/helm-shim",
          "chmod 755 /custom-tools/*",
        ])]
        volumeMounts = [
          { name = "custom-tools", mountPath = "/custom-tools" },
        ]
      },
    ]

    volumes = [
      { name = "custom-tools", emptyDir = {} },
    ]

    volumeMounts = [
      # subPath mount shadows the real helm binary with the shim, so every
      # `helm` invocation inside repo-server resolves to helm-shim.
      { name = "custom-tools", mountPath = "/usr/local/bin/helm", subPath = "helm-shim" },
      { name = "custom-tools", mountPath = "/custom-tools" },
    ]

    envFrom = [
      { secretRef = { name = local.shim_credentials_secret } },
    ]

    # FACETS_ARGOCD_NAMESPACE tells the resolver which namespace to LIST
    # Applications in. Only needed when ArgoCD isn't in the default "argocd".
    env = local.argocd_namespace != "argocd" ? [
      { name = "FACETS_ARGOCD_NAMESPACE", value = local.argocd_namespace },
    ] : []
  }

  # Merge the shim's repoServer block over any user-supplied repoServer values
  # so custom_values can still tune resources, replicas, etc. The shim's own
  # keys win — a half-applied shim is worse than none.
  #
  # jsonencode/jsondecode erases the differing object types of the two branches
  # (Terraform requires both arms of a conditional to have identical types).
  argocd_repo_server_custom = lookup(local.argocd_values, "repoServer", {})
  argocd_repo_server = jsondecode(local.shim_enabled ? jsonencode(merge(
    local.argocd_repo_server_custom,
    local.shim_repo_server_values,
  )) : jsonencode(local.argocd_repo_server_custom))
}

# ── CP credentials Secret ───────────────────────────────────────────────────
#
# Created BY THIS MODULE. The user supplies only cp_username and cp_token in the
# spec (the token ideally as ${blueprint.self.secrets.*}); everything else here
# is module-owned, so there is no k8s_resource to author and no Secret name to
# keep in sync.
#
# It MUST be a kubernetes_secret resource, not local-exec + kubectl: kubectl in
# a provisioner runs in the release pod and authenticates as THAT pod's identity
# (system:serviceaccount:default:facets-release-pod) - the control plane's own
# cluster, not the target. Only Terraform resources reach the target cluster,
# via the kubernetes provider injected from @facets/kubernetes-details.
#
# Trade-off accepted: this puts the token in Terraform state. That state already
# holds cloud credentials, and the alternative (kubectl) does not work at all.

resource "terraform_data" "shim_credentials_precondition" {
  count = local.shim_enabled ? 1 : 0

  input = local.shim_credentials_secret

  lifecycle {
    precondition {
      condition = local.shim_cp_username != "" && local.shim_cp_token != "" && local.shim_cp_url != "https://"
      error_message = join(" ", [
        "facets_shim.enabled is true but cp_username and/or cp_token is empty.",
        "The shim authenticates to the control plane as a Facets user; create a",
        "dedicated service user, generate its personal token in the CP UI",
        "(Account Settings > Personal Token - there is no API for this), store it",
        "as a project secret, and set:",
        "cp_username: <that user>, cp_token: $${blueprint.self.secrets.<NAME>}.",
        "Without them argocd-repo-server starts but every render containing a",
        "$${facets:...} reference fails closed with a 401 from the control plane.",
        "(If cp_username/cp_token are set and this still fires, TF_VAR_cc_host",
        "was not injected into the release.)",
      ])
    }
  }
}

# NAMESPACE
#
# Owned by this module, because the Secret must exist before the argo-cd release
# finishes: repo-server mounts it via envFrom and the release runs with
# wait = true, so create_namespace on the release itself is too late.
resource "kubernetes_namespace_v1" "argocd" {
  count = local.shim_enabled ? 1 : 0

  metadata {
    name = local.argocd_namespace
  }

  lifecycle {
    # ArgoCD's chart adds its own labels to this namespace; don't fight it.
    ignore_changes = [metadata]
  }
}

# TF_VAR_cc_host is injected into every release, but declaring it as a Terraform
# variable is rejected by the platform's module validation ("Module variables
# validation failed"), so it is read from the environment in a shell instead.
data "external" "cp_host" {
  count = local.shim_enabled ? 1 : 0

  program = ["/bin/sh", "-c", "printf '{\"url\":\"https://%s\"}' \"$${TF_VAR_cc_host:-}\""]
}

resource "kubernetes_secret_v1" "facets_cp_credentials" {
  count = local.shim_enabled ? 1 : 0

  metadata {
    name      = local.shim_credentials_secret
    namespace = local.argocd_namespace
    labels = {
      "app.kubernetes.io/part-of" = "facets-argo-shim"
    }
  }

  data = {
    # The resolver derives its base URL from this; https:// is required.
    # cc_host is not a module variable (the platform rejects extra variables),
    # so it is read from the injected TF_VAR_cc_host env var via data.external.
    FACETS_CP_URL      = local.shim_cp_url
    FACETS_CP_USERNAME = local.shim_cp_username
    FACETS_CP_TOKEN    = local.shim_cp_token
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace_v1.argocd, terraform_data.shim_credentials_precondition]
}

# ORDERING — load-bearing:
#   namespace -> secret -> repo-server Ready -> helm_release.argocd completes
#
# helm_release.argocd depends_on the Secret (see helm-argocd.tf), never the
# reverse. Inverting it deadlocks: repo-server sits in
# CreateContainerConfigError with `secret "..." not found` until the 600s wait
# expires and the release fails.

# ── RBAC ────────────────────────────────────────────────────────────────────
#
# `list` on applications.argoproj.io in ArgoCD's own namespace — nothing more.
# No get, no watch, no write, no other resource, no cluster-wide grant. This is
# the only way the resolver can identify which Facets project/environment a
# given render belongs to; there is no env-var fallback.

resource "kubernetes_role_v1" "facets_shim_app_reader" {
  count = local.shim_enabled ? 1 : 0

  metadata {
    name      = local.shim_rbac_name
    namespace = local.argocd_namespace
  }

  rule {
    api_groups = ["argoproj.io"]
    resources  = ["applications"]
    verbs      = ["list"]
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_role_binding_v1" "facets_shim_app_reader" {
  count = local.shim_enabled ? 1 : 0

  metadata {
    name      = local.shim_rbac_name
    namespace = local.argocd_namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.facets_shim_app_reader[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = local.shim_repo_server_sa
    namespace = local.argocd_namespace
  }
}
