# clickhouse_keeper / k8s / 1.0

Deploys a ClickHouse Keeper ensemble (replication coordination) as a
`ClickHouseKeeperInstallation` (CHK) custom resource, applied through a small
local Helm chart under `chart/` so Terraform never needs the CRD registered at
plan time. The Altinity operator (an input dependency, `clickhouse_operator`)
installs the CRD and must be deployed first — Facets orders it via the input.

- **CRD apiVersion / kind**: `clickhouse-keeper.altinity.com/v1` /
  `ClickHouseKeeperInstallation`.
- **Service DNS (`service_host` output)**:
  `keeper-<keeper_name>.<namespace>.svc.cluster.local`. The Altinity operator
  creates the client Service for a CHK named `<keeper_name>` as
  `keeper-<keeper_name>`. Verify against your operator version; if it differs,
  update the `service_host` expression in `outputs.tf`.
- **Port**: `2181` (Keeper client port).

## Dedicated node-pool placement (`node_pool` input)

Optional input `node_pool` (`@facets/kubernetes_nodepool`, `optional: true`).
Wire it to pin the Keeper ensemble onto a dedicated, tainted node pool; leave it
unwired and the module schedules anywhere (no `nodeSelector`/`tolerations`
rendered). Placement is read defensively in `main.tf`:

- `node_selector` — a **merge** of the output's custom `node_selector` and the
  always-present GKE pool label:
  `merge(try(var.inputs.node_pool.attributes.node_selector, {}), local.node_pool_name != "" ? { "cloud.google.com/gke-nodepool" = local.node_pool_name } : {})`
  → `spec.templates.podTemplates[].spec.nodeSelector` (guarded by `{{- if }}`).
- `taints` ← `try(var.inputs.node_pool.attributes.taints, [])`, each
  `{key,value,effect}` mapped to a toleration `{key,value,effect,operator:"Equal"}`
  → `spec.templates.podTemplates[].spec.tolerations` (guarded by `{{- if }}`).

**Why the GKE pool label (eu-prod pilot finding):** the node_pool output's
custom `node_selector` arrived **empty** at apply. Every node in a GKE pool
reliably carries `cloud.google.com/gke-nodepool=<pool-name>`, and the output
always exposes `node_pool_name` — so the module pins on that label. When
`node_pool` is unwired, `node_pool_name` is `""`, the merge yields `{}`, and no
`nodeSelector` renders.

The `kubernetes_node_pool/gcp/1.0` output emits `taints[].effect` already in
Kubernetes form (`NoSchedule`/`PreferNoSchedule`/`NoExecute`), so the effect is
passed through verbatim — no `NO_SCHEDULE`→`NoSchedule` normalization is needed.
`variables.tf` types `node_selector` as `map(string)` (not the schema-default
empty `object({})`, which silently drops label keys during Terraform coercion).
If a future `raptor module` mutation regenerates `variables.tf`, re-widen
`node_selector` back to `map(string)`.

### podTemplate application + ensemble spread

The CHK references its podTemplate via `spec.defaults.templates.podTemplate:
default` (+ `dataVolumeClaimTemplate: default`). **This reference is required** —
an unreferenced podTemplate named `default` is ignored by the operator, which is
why the Keeper's `nodeSelector` did not reach the pods in the eu-prod pilot until
the `defaults` block was added.

The Keeper relies on `nodeSelector` pinning only — no pod anti-affinity and no
`podDistribution` is injected (the CHK layout differs from the CHI; the raw
`podAntiAffinity` earlier versions rendered was removed after the pilot).
