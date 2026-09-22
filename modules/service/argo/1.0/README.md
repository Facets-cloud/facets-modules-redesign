# service / argo / 1.0

Deploys a service to Kubernetes through ArgoCD as an **ApplicationSet**, with
the facets-argo-shim identity annotations injected so `${facets:...}` references
inside the deployed chart resolve against this project and environment.

Redesign of CoinSwitch's `service/argo/2.1` against the `facets-modules-redesign`
standards.

**Cloud-agnostic.** This flavor creates no cloud resources of its own — only an
ArgoCD `ApplicationSet` — so it runs unchanged on GKE, EKS, AKS or any conformant
cluster. It needs no cloud account wired. Where a service also needs a cloud
identity or a DNS record, use the dedicated intents for that cloud
(`google_workload_identity`, `dns_record`, …) and inject whatever the chart needs
through `helm_values`.

`service/argo_gcp` is the GCP-specific sibling: same core, plus GCP Workload
Identity bindings and a Cloud DNS record.

## What changed from 2.1

The core problem was CoinSwitch-specific chart knowledge hardcoded into a
general flavor — `locals.tf` alone was 412 of 769 lines.

| CoinSwitch 2.1 | argo 1.0 |
|---|---|
| k8s service name guessed via 4 lookup patterns + a `gateway-consumer` special case | publishes the Helm release name — stable and knowable |
| `spec.application` — the entire ApplicationSet as raw YAML | structured `chart` / `sync_policy` / `helm_values`, plus an `advanced` escape hatch |
| no `intentDetails` | present (RULE-021) |
| no `artifact_inputs` | `primary` → `spec.release.image` (the service standard requires it) |
| no shim gate | precondition fails the plan if refs are used without a shim |
| 769 lines of Terraform | 468, of which 273 are code |

Kept from 2.1: the five shim annotations and the `facets_references` digest
pattern — 2.1 is where that design originated.

Dropped relative to `argo_gcp`: `workload_identity` and `dns_record`, and with
them the `cloud_account` input and the `google` provider. See **Not included**.

**Why structured, not the YAML blob:** all 14 live `service/argo` resources in
the coinswitch project use `ApplicationSet` + a `list` generator, zero
multi-source, and every source maps exactly onto
`repoURL`/`path`/`targetRevision`/`helm.releaseName`/`helm.valueFiles`. The one
resource using `ignoreDifferences` is covered by `spec.advanced`.

## Inputs

| Input | Type | Required |
|---|---|---|
| `kubernetes_details` | `@facets/kubernetes-details` | yes (`output_name: attributes`) |
| `argo_stack` | `@facets/argo-stack` | yes — supplies the ArgoCD namespace and `shim_enabled` |

Two inputs, neither cloud-specific. There is deliberately no `cloud_account`: the
GCP flavor needs one only for Workload Identity and Cloud DNS, and dropping those
is what makes this flavor portable.

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
| `advanced` | `ignore_differences`, `sync_options`, `application_overrides` | escape hatches |
| — | `facets_references` | **shim-maintained — do not hand-edit** |

### Cloud identity for the workload

This flavor binds no cloud identity. Create one with the dedicated intent for
your cloud (`google_workload_identity`, an AWS IAM role, an Azure managed
identity), then annotate the chart's ServiceAccount through `helm_values`:

```yaml
helm_values:
  myapp:
    serviceaccount:
      annotations:
        iam.gke.io/gcp-service-account: my-sa@my-project.iam.gserviceaccount.com
        # or eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/my-role
```

The exact path depends on the chart; `helm_values` is deep-merged one level per
top-level key, so this coexists with any other values the chart needs.

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

`service_account_arn` is empty for the same reason: this flavor creates no cloud
identity at all.

## Verified

The core of this flavor is the same code as `service/argo_gcp/1.0`, which was
exercised end to end in facetsdemo (`argo-test`, a real GKE cluster): the
ApplicationSet and its five shim annotations, `${facets:...}` resolution for
variables and resource outputs, the `facets_references` callback and the
`facets_references_hash` re-render trigger, `sync_policy` (prune, selfHeal,
retry, syncOptions), `helm_values`, `annotations`, `advanced`, and
`artifact_inputs` driving a full CI→deploy loop from a changed artifact URI
alone.

What is **new here and not yet exercised on a live cluster** is the absence of
the cloud pieces: no `cloud_account` input, no `google` provider, no
`workload_identity` or `dns_record`. Terraform validates and
`raptor create iac-module --dry-run` passes. Proving the multi-cloud claim
properly needs a deploy on a non-GCP cluster (EKS or AKS), which has not been
done.

## Not included

`workload_identity` and `dns_record` — deliberately. Both were inherited from
CoinSwitch's 2.1, both duplicate dedicated intents, and across CoinSwitch's 34
Argo services only 5 used `dns_record` and 1 used `workload_identity`. Keeping
them is what forced a mandatory GCP `cloud_account` input and made the module
GCP-only. Use `service/argo_gcp` when you want them.
