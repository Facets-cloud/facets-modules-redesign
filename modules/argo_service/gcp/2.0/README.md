# argo_service / gcp / 2.0

Deploys a service to GKE through ArgoCD as an **ApplicationSet**, with the
facets-argo-shim identity annotations injected so `${facets:...}` references
inside the deployed chart resolve against this project and environment.

Deployment (CD) only — image builds are out of scope for this module.

## Inputs

| Input | Type | Required | Purpose |
|---|---|---|---|
| `kubernetes_details` | `@facets/kubernetes-details` | yes | GKE cluster; provides the `kubernetes` + `helm` providers |
| `argo_stack` | `@facets/argo-stack` | yes | Supplies the ArgoCD namespace and orders this module after Argo is running |

## Spec

| Group | Field | Notes |
|---|---|---|
| — | `namespace` | **required.** Target namespace; created automatically |
| — | `argocd_project` | AppProject for the generated Application (default `default`) |
| `chart` | `repo_url`, `path`, `values_path` | **required** |
| `chart` | `revision` | branch/tag/commit (default `develop`) |
| `chart` | `release_name` | defaults to the blueprint resource name |
| `sync_policy` | `automated`, `auto_prune`, `self_heal`, `preserve_on_delete`, `retry.limit` | |
| — | `helm_values` | merged into `spec.source.helm.valuesObject` |
| — | `annotations` | extra Application annotations (`facets.cloud/*` always win) |
| — | `facets_references` | **shim-maintained — do not hand-edit** |

## The shim contract

The generated Application carries five annotations, on the Application
**template** metadata so they propagate to the object the shim actually reads:

```yaml
facets.cloud/project: <project>
facets.cloud/environment: <env>
facets.cloud/resource-type: argo_service
facets.cloud/resource-name: <resource>
facets.cloud/references-field: facets_references
```

The first two are what make `${facets:...}` refs resolve at all — without them
any render containing a ref **fails closed**. The last three opt into the
consumed-references callback.

### Why `facets_references` exists

The shim resolves refs at *render* time, so a Facets release that changes a
referenced value would never reach an already-deployed Application — Argo only
re-syncs when the CR changes. After each successful render the shim writes the
expressions it consumed to `spec.facets_references.<env>.expressions`. The
Control Plane resolves them before this module runs, and the module folds a
**sha1 digest** of the resolved values into the Application as
`valuesObject.facets_references_hash`. Any change to a referenced value
changes the digest → mutates the CR → Argo re-renders and goes OutOfSync.

Digest only, deliberately: resolved values may be sensitive and must not land
in a CR that Argo stores, diffs, and displays.

The callback **fails open** — with a read-only CP token the shim warns and
renders normally; refs still resolve, but this release→re-render loop won't
fire.

## Cluster prerequisites

Not created by this module:

- the shim installed in `argocd-repo-server`;
- `list` on `applications.argoproj.io` in the Argo CD namespace, plus
  `automountServiceAccountToken: true` on repo-server;
- `FACETS_CP_URL` / `FACETS_CP_USERNAME` / `FACETS_CP_TOKEN` on repo-server;
- CP **write** access for the callback, `VIEW_SECRETS` for `.secrets.` refs.

Without these the annotations are inert and refs don't resolve — harmless for
charts that use no refs, and a valid way to stage a rollout.

## Outputs — `@facets/argo_service`

`applicationset_name`, `application_name`, `argocd_project`,
`argocd_namespace`, `resource_namespace`, `resource_name` (v1 alias of
`service_name`), `service_name`, `release_name`, `chart_repo_url`,
`chart_path`, `target_revision`, `values_path`.

## Migrating from 1.0

1. `charts_repo_url` / `charts_repo_branch` / `chart_path` / `values_path` move
   under `chart` (as `repo_url` / `revision` / `path` / `values_path`).
2. `sync_policy` keeps its three fields and gains `automated` + `retry`.
3. Replace the `argo_cd` / `argo_workflows` / `argo_events` inputs with one
   `argo_stack` input.
4. Drop the CI fields (`source_repo`, `source_branch`, `image_registry`,
   `build_steps`, `detect_folders`, `build_args`, `kaniko_image`,
   `workflow_service_account`, `workflow_ttl_seconds`) — this module no longer
   creates the Sensor or the build Workflow. Whatever owns image builds must
   own them separately.
