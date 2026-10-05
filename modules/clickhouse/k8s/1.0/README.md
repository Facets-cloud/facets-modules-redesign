# clickhouse / k8s / 1.0

Deploys a ClickHouse cluster as a `ClickHouseInstallation` (CHI) custom
resource, applied through a small local Helm chart under `chart/` (no plan-time
CRD schema check). Inputs `clickhouse_operator` (CRDs) and `clickhouse_keeper`
(coordination) are declared dependencies, so Facets deploys them first.

- **CRD apiVersion / kind**: `clickhouse.altinity.com/v1` /
  `ClickHouseInstallation`.
- **Keeper wiring**: `configuration.zookeeper.nodes[0]` is populated from
  `var.inputs.clickhouse_keeper.attributes.service_host` and `.port`.
- **Service DNS (`service_host` output)**:
  `clickhouse-<cluster_name>.<namespace>.svc.cluster.local`. Altinity's CHI
  service is `clickhouse-<chi-name>`; the CHI name here is `<cluster_name>`.
  Verify against your operator version and adjust `outputs.tf` if it differs.
- **Ports**: HTTP `8123`, native TCP `9000`.

## Users (`users_json`)

`users_json` is a JSON array. Each element:

```json
{
  "name": "app",
  "password_secret": "clickhouse-app-password",
  "password_sha256_hex": "<optional precomputed sha256 hex>",
  "networks": ["::/0"],
  "profile": "default"
}
```

- **No plaintext passwords are hardcoded.** `password_secret` is the *name* of a
  Facets secret intended to hold the credential; wire it operationally (e.g. via
  a dedicated `--secret` spec field / external-secret) — the module does not
  resolve secret values from inside a JSON string.
- `password_sha256_hex` (optional) renders directly into the CHI as
  `<name>/password_sha256_hex`. Omit both fields for a passwordless user.
- `networks` → `<name>/networks/ip`; `profile` → `<name>/profile`.

`settings_json` is a JSON object merged into `configuration.settings`.

## Dedicated node-pool placement (`node_pool` input)

Optional input `node_pool` (`@facets/kubernetes_nodepool`, `optional: true`).
Wire it to pin ClickHouse onto a dedicated, tainted node pool; leave it
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
custom `node_selector` arrived **empty** at apply, so pods landed on regular
nodes. Every node in a GKE pool reliably carries
`cloud.google.com/gke-nodepool=<pool-name>`, and the output always exposes
`node_pool_name` (e.g. `clickhouse-node-pool`) — so the module pins on that
label. Any custom labels from the output still merge in alongside it. When
`node_pool` is unwired, `node_pool_name` is `""`, the merge yields `{}`, and no
`nodeSelector` renders.

The `kubernetes_node_pool/gcp/1.0` output emits `taints[].effect` already in
Kubernetes form (`NoSchedule`/`PreferNoSchedule`/`NoExecute`), so the effect is
passed through verbatim — no `NO_SCHEDULE`→`NoSchedule` normalization is needed.
`variables.tf` types `node_selector` as `map(string)` (not the schema-default
empty `object({})`, which silently drops label keys during Terraform coercion).
If a future `raptor module` mutation regenerates `variables.tf`, re-widen
`node_selector` back to `map(string)`.

### Replica spread (operator-native podDistribution)

Replica spreading is delegated to the Altinity operator via `podDistribution`
(`ClickHouseAntiAffinity` + `ReplicaAntiAffinity`) — **not** a raw
`podAntiAffinity` in the podTemplate.

`podDistribution` is a **direct child of the podTemplate entry** —
`spec.templates.podTemplates[].podDistribution`, a sibling of that entry's
`spec:` — matching Altinity's `chi-examples/02-templates-01` reference. The
podTemplate is applied because the CHI references it via
`spec.defaults.templates.podTemplate: default` (+ `dataVolumeClaimTemplate`).

- **eu-prod pilot findings:** (1) a raw `podAntiAffinity` injected into the CHI
  podTemplate `spec` made the operator loop the StatefulSet `Update→Recreate` and
  stall with no STS/pod created. (2) Placing `podDistribution` under the cluster
  entry (`configuration.clusters[].templates`) also broke the STS reconcile — it
  belongs on the podTemplate. Moving it there lets the operator manage the spread
  as part of its own reconcile, no churn.
