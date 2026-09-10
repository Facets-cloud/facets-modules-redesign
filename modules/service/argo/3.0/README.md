# service / argo / 3.0

Deploys a service to Kubernetes through ArgoCD as an **ApplicationSet**, with
the facets-argo-shim identity annotations injected so `${facets:...}` references
inside the deployed chart resolve against this project and environment.

Redesign of `service/argo/2.1` against the `facets-modules-redesign` standards.

## What changed from 2.1

The core problem was CoinSwitch-specific chart knowledge hardcoded into a
general flavor — `locals.tf` alone was 412 of 769 lines.

| 2.1 | 3.0 |
|---|---|
| `chart_default_values_roots` — a table of 18 CoinSwitch chart names, used to *guess* each chart's internal values root | explicit `values_root` per service account |
| k8s service name guessed via 4 lookup patterns + a `gateway-consumer` special case | publishes the Helm release name — stable and knowable |
| `spec.application` — the entire ApplicationSet as raw YAML | structured `chart` / `sync_policy` / `helm_values`, plus an `advanced` escape hatch |
| no `intentDetails` | present (RULE-021) |
| no `artifact_inputs` | `primary` → `spec.release.image` (the service standard requires it) |
| no shim gate | precondition fails the plan if refs are used without a shim |
| 769 lines of Terraform | ~480 |

Kept from 2.1: the five shim annotations and the `facets_references` digest
pattern (2.1 is where that design originated), GCP Workload Identity, and Cloud
DNS records.

**Why structured, not the YAML blob:** all 14 live `service/argo` resources in
the coinswitch project use `ApplicationSet` + a `list` generator, zero
multi-source, and every source maps exactly onto
`repoURL`/`path`/`targetRevision`/`helm.releaseName`/`helm.valueFiles`. The one
resource using `ignoreDifferences` is covered by `spec.advanced`.

## Inputs

| Input | Type | Required |
|---|---|---|
| `kubernetes_details` | `@facets/kubernetes-details` | yes (`output_name: attributes`) |
| `cloud_account` | `@facets/gcp_cloud_account` | yes |
| `argo_stack` | `@facets/argo-stack` | yes — supplies the ArgoCD namespace and `shim_enabled` |

## Spec

| Group | Field | Notes |
|---|---|---|
| — | `namespace` | **required** — created automatically |
| — | `argocd_project` | AppProject for the generated Application |
| `chart` | `repo_url`, `path` | **required** |
| `chart` | `revision` | branch/tag/commit, default `HEAD` |
| `chart` | `values_path`, `release_name` | release name defaults to the resource name |
| `release` | `image`, `image_values_path` | image normally set by the wired artifact; `image_values_path` is the dot-path in chart values, e.g. `myapp.image` |
| `sync_policy` | `automated`, `auto_prune`, `self_heal`, `preserve_on_delete`, `retry.limit` | |
| — | `helm_values` | merged into `spec.source.helm.valuesObject` |
| `workload_identity` | `service_accounts.<name>.{ksa_name, values_root, roles, aws}` | see below |
| `dns_record` | `enabled`, `zone_name`, `name`, `target`, `ttl` | A or CNAME inferred from the target |
| `advanced` | `ignore_differences`, `sync_options`, `application_overrides` | escape hatches |
| — | `facets_references` | **shim-maintained — do not hand-edit** |

### Workload Identity

Each entry creates a GCP service account, grants its roles, binds
`workloadIdentityUser` to the chart-owned Kubernetes ServiceAccount, and injects
the `iam.gke.io/gcp-service-account` annotation into the chart values at
`<values_root>.serviceaccount.annotations`.

```yaml
workload_identity:
  service_accounts:
    myapp:
      ksa_name: myapp-sa      # defaults to the map key
      values_root: myapp      # defaults to the map key
      roles:
        pubsub: { role: roles/pubsub.publisher }
```

`values_root` is the field that replaces 2.1's hardcoded chart table. State it
explicitly rather than relying on the module to guess.

An entry may set only `aws` (with no `roles`) for a cross-cloud workload — no
GCP service account is created in that case.

## Writing `${facets:...}` refs

Refs belong in the **chart's own values files in git**, where they need no
escaping.

To put one in `spec.helm_values` instead, it **must** be written `$${facets:...}`:

```json
"helm_values": { "image": { "tag": "v5-$${facets:kubernetes_cluster.gke.out.attributes.cluster_location}" } }
```

Three layers each parse `${...}` — the CP expression engine, Terraform (the CP
writes the spec into a generated `.tf.json`), and the shim. Terraform consumes
the doubled dollar, leaving exactly the single-dollar form the shim resolves.
Without it the release fails with `Extra characters after interpolation
expression`. Note `raptor apply --dry-run` does **not** catch this — it never
generates the Terraform.

Also: `${facets:blueprint.self.*}` is a hard CP validation error (the CP owns
the `blueprint` namespace), while `${facets:<type>.<name>.out.*}` is only a
warning. Resource-output refs are the usable form in spec fields.

## Shim gate

`argo_stack` publishes `shim_enabled`. This module carries a `precondition` that
**fails the plan** when the service uses `${facets:...}` refs but the stack has
no shim — otherwise the release goes green and the render fails later inside
ArgoCD, where Terraform cannot see it. Ref-free services still deploy to a
shim-less cluster.

## Outputs — `@facets/service`

`namespace`, `resource_name`, `resource_type`, `service_name`,
`selector_labels`, `service_account_arn` — exactly the declared contract
(RULE-012), so downstream consumers stay flavor-agnostic.

`service_name` and `selector_labels` are published **empty on purpose**. This
module hands a chart to ArgoCD and Argo renders it, so the Kubernetes objects the
chart produces — their names, their labels, whether a Service exists at all — are
not knowable here. Verified against the tested `demo-app` chart: its pods carry
`app=demo-app`, not `app.kubernetes.io/instance=demo-app`, and the chart creates
no Service whatsoever, so both earlier guesses were wrong in the one case that
could be checked. A consumer such as `load_balancer/gcp` wires `selector_labels`
straight into a backend and would have built a load balancer matching no pods.
Empty means "not determinable from here", which lets a consumer fail loudly.

`service_account_arn` **is** knowable: real whenever `workload_identity` created
a GCP service account, empty when the chart brings its own.

## Verified

Every spec block was exercised end to end in facetsdemo `argo-test`/`dev`,
against a real GKE cluster (`gke-metadata-server-enabled=true`) and a real Cloud
DNS zone.

| Block | Evidence |
|---|---|
| `chart`, `namespace`, `argocd_project` | ApplicationSet created in the argo namespace; app `Synced`/`Healthy` |
| `sync_policy` | `automated.prune=true`, `automated.selfHeal=true`, `retry.limit=3`, and the user's `sync_options` appended to the module's own |
| `helm_values` | `replicaCount: 2` → 2 pods |
| `release` + `artifact_inputs` | see below |
| `workload_identity` | `google_service_account` + `google_project_iam_member` (`roles/storage.objectViewer`) + `google_service_account_iam_member` (`workloadIdentityUser` → `svc.id.goog[demo/demo-app]`); the `iam.gke.io/gcp-service-account` annotation landed on the chart-owned ServiceAccount at the declared `values_root` |
| `dns_record` | all three branches — an A record, a CNAME (trailing dot added automatically when the target is a hostname), and a comma-separated target producing one A record with multiple rrdatas. All resolved publicly via `8.8.8.8` |
| `advanced` | `ignoreDifferences`, extra `syncOptions`, and `application_overrides` (`revisionHistoryLimit: 5`) all reached the Application |
| `annotations` | the custom annotation coexists with all five `facets.cloud/*` |
| `facets_references` | refs resolved in-cluster; the digest tracks them |

**Artifacts.** `artifact_inputs` is not wired as a resource input — the Control
Plane rejects that (`input "primary" is not declared in module`). It is consumed
by referencing the artifact from the spec:

```
release.image             = ${blueprint.self.artifacts.demo-app}
release.image_values_path = imageUri
```

Bumping only the artifact URI — no spec change, no git commit — then releasing
rolled the pods, which is the whole CI→deploy loop:

```
~ artifact_url = "...nginx:1.26-alpine" -> "...nginx:1.29-alpine"
- imageUri     = "...nginx:1.26-alpine"
+ imageUri     = "...nginx:1.29-alpine"
```

Note `image_values_path` names a **single full-URI** value. Charts that split
`image.repository` and `image.tag` and concatenate them need a dedicated
full-URI field, or injecting into `repository` alone yields `repo:tag:tag`.

**Value merging.** All four value sources were verified live in one
`valuesObject` — `helm_values`, the injected image, the Workload Identity
annotation, and the references digest. A shallow `merge()` silently drops keys
here (it produced an invalid `nginx:1.29-alpine:1.27-alpine`), which is why
`locals.tf` merges one level into each top-level key.

## Untested

Nothing in the spec. `workload_identity.<key>.aws` (the projected-token /
`eks.amazonaws.com` annotation path) is implemented but only meaningful on EKS,
so it was not exercised on this GKE cluster.
