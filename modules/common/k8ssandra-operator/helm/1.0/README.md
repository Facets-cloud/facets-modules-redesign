# K8ssandra Operator (helm)

Installs the [k8ssandra-operator](https://github.com/k8ssandra/k8ssandra-operator)
via its official Helm chart (`https://helm.k8ssandra.io/stable`, chart
`k8ssandra-operator`, version `0.30.1`). The chart bundles `cass-operator`,
which does the actual Cassandra pod orchestration.

## Key decisions

- **Cluster-scoped watch**: the chart default (`global.clusterScoped: false`)
  watches only the operator's own namespace. This module hardcodes
  `global.clusterScoped: true` so `cassandra/k8ssandra` instances can be
  created in environment namespaces.
- The operator is a prerequisite for every `cassandra/k8ssandra` instance —
  wire it via the `@facets/k8ssandra-operator` output.

## Inputs

| Name | Type | Notes |
|---|---|---|
| `kubernetes_cluster` | `@facets/kubernetes-details` | provides kubernetes + helm providers |
| `node_pool` | `@facets/kubernetes_nodepool` | optional; scheduling for operator pods |

## Outputs

| Key | Type |
|---|---|
| `default` | `@facets/k8ssandra-operator` |
