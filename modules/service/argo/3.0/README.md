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
(RULE-012), so downstream consumers stay flavor-agnostic. Argo-specific
coordinates are deliberately not published here; a consumer needing those wants
`argo_service`.

## Verified

Deployed as `service/svc-guestbook` in facetsdemo `argo-test`/`dev`, succeeded
on the first release:

```
svc-guestbook-helm-guestbook -> gcr.io/google-samples/gb-frontend:v5-asia-east1
```

Synced; the ref resolved; 5/5 shim annotations present with
`facets.cloud/resource-type: service`; and the shim's callback wrote
`facets_references.dev.expressions` back to the blueprint resource.

## Not yet tested

`workload_identity`, `dns_record`, and `artifact_inputs` are implemented but
were not exercised by that test.
