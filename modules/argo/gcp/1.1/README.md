# argo / gcp / 1.1

Deploys the Argo stack on GKE — ArgoCD, Argo Workflows, Argo Events, Argo
Rollouts — each independently toggleable, plus Workload Identity for the
Workflows service account.

**New in 1.1:** optionally installs the
[facets-argo-shim](https://github.com/Facets-cloud/facets-argo-shim) into
`argocd-repo-server`, so `${facets:...}` references inside charts deployed by
ArgoCD resolve against the Facets control plane. Also publishes
`shim_enabled` / `shim_version` on `@facets/argo-stack` so consumers can gate on
it, and makes the Argo Events namespace configurable
(`spec.events.namespace`) instead of hardcoding the ArgoCD namespace.

## Inputs

| Input | Type | Required |
|---|---|---|
| `kubernetes_details` | `@facets/kubernetes-details` | yes (`output_name: attributes`) |
| `cloud_account` | `@facets/gcp_cloud_account` | yes |
| `node_pool` | `@facets/gke_node_pool_details` | no (`output_name: attributes`) |

## Enabling the shim

```yaml
spec:
  argocd:
    enabled: true
    namespace: argocd
    facets_shim:
      enabled: true
      image: docker.io/facetscloud/facets-argo-shim:v0.13.1
      argocd_image: quay.io/argoproj/argocd:v3.3.5   # match your ArgoCD version
      cp_username: argo-shim@yourorg.com
      cp_token: ${blueprint.self.secrets.ARGO_SHIM_CP_TOKEN}
```

The module then adds to the argo-cd release's `repoServer` values:

- two initContainers — one copying **Argo's own helm** to
  `/custom-tools/helm-real` (version-exact by construction), one copying the
  shim's `facets-resolver` + `helm-shim` from `/opt/facets`;
- a shared `custom-tools` emptyDir, with a `subPath` mount shadowing
  `/usr/local/bin/helm` with the shim;
- `envFrom` the credentials Secret;
- `automountServiceAccountToken: true` (upstream ships this `false`);
- `FACETS_ARGOCD_NAMESPACE` when ArgoCD is not in `argocd`.

It also creates a Role + RoleBinding (named
`facets-shim-app-reader-<resource name>`) granting `list` on
`applications.argoproj.io` — the only way the resolver can identify which
project/environment a render belongs to.

## Setup: 3 one-time steps, then just spec

The module creates the Kubernetes Secret, the namespace, and the RBAC itself.
You only supply an identity.

**Once per control plane:**

1. Create a dedicated Facets user, e.g. `argo-shim@yourorg.com`. It needs read
   access to the project, `VIEW_SECRETS` if any chart uses
   `blueprint.self.secrets.*` refs, and blueprint **write** for the
   consumed-references callback.
2. Generate that user's personal token: **Account Settings → Personal Token**
   in the CP UI. There is no API for this and it is shown only once.
3. Store it as a project secret, e.g. `ARGO_SHIM_CP_TOKEN`.

**Then per Argo stack, in the spec:**

```yaml
spec:
  argocd:
    enabled: true
    facets_shim:
      enabled: true
      cp_username: argo-shim@yourorg.com
      cp_token: ${blueprint.self.secrets.ARGO_SHIM_CP_TOKEN}
```

That is the whole user-facing surface. No `k8s_resource` to author, no Secret
name to keep in sync, no input to wire.

### Why the token cannot be automatic

The resolver talks to `/cc-ui/v1/...` endpoints, which use basic auth with a
Facets **user** identity. The `TF_VAR_cc_auth_token` the platform injects into
every release is an internal *deployer* token for `/cc/v1/...`; it returns
**401** on every `/cc-ui/v1` endpoint (verified). And there is no API to mint a
personal token. So a scoped service user must exist out of band — but nothing
beyond that is asked of the user.

Making this fully automatic needs a platform change: a shim-usable service
token injected alongside `TF_VAR_cc_auth_token`, or `/cc/v1` equivalents for
the seven read endpoints plus the resource write.

### What the resolver needs the identity for

| Capability | Used for | If missing |
|---|---|---|
| Read project/env metadata | all resolution | nothing resolves |
| Read resource outputs | `${facets:<type>.<name>.out.*}` | those refs fail closed |
| `VIEW_SECRETS` | `blueprint.self.secrets.*` | only secret refs fail |
| Blueprint **write** | the `facets_references` callback | refs still resolve; callback warns and skips, so Facets-side re-renders never fire |

### Ordering

Handled by the module. `helm_release.argocd` depends on the Secret, giving:

```
namespace -> secret -> repo-server Ready -> helm_release completes
```

The release runs with `wait = true` (600s) and repo-server mounts the Secret via
`envFrom`, so it cannot become Ready before the Secret exists. A `precondition`
fails the plan immediately when `cp_username`/`cp_token` are missing, rather
than letting it surface 10 minutes later as a Helm timeout whose real cause is
`CreateContainerConfigError: secret not found`.

### A note on Terraform state

Because the token flows through a Terraform resource, it is stored in Terraform
state. That state already holds cloud credentials. The alternative — `kubectl`
in a `local-exec` — does not work at all: it runs in the release pod and
authenticates as `system:serviceaccount:default:facets-release-pod`, i.e. the
control plane's own cluster, never the target.

## Consumer gate

`@facets/argo-stack` publishes:

| Attribute | Meaning |
|---|---|
| `shim_enabled` | `true` only once the shim values AND the RBAC are in place |
| `shim_version` | image tag of the installed shim, empty when disabled |

`service/argo/3.0` carries a `precondition` on `shim_enabled` and **fails
the plan** if a service uses `${facets:...}` refs without a shim — otherwise
the release goes green and the render fails later inside ArgoCD, where
Terraform cannot see it.

## Notes

- `spec.events.namespace` defaults to the ArgoCD namespace (1.0 behaviour).
  Set it to a dedicated namespace such as `argo-events` if Argo Events runs
  separately — whatever is set is what `events_namespace` publishes.
- Disabling `workflows` skips the GCP service account and Workload Identity
  binding along with the chart.
