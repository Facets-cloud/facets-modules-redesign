# Blueprint Templates

This directory holds curated bundles of Facets blueprint resources. Each
subdirectory is one template. Raptor's `get bp-templates` command
fetches templates from this repo over HTTPS at runtime — consumers do
**not** need to clone the repo manually.

## Layout

```
templates/
├── README.md                  (this file)
└── <template-name>/
    ├── template.yaml          (metadata; required)
    └── *.json                 (resource JSONs; one per file)
```

## Architecture

Templates are split into two tiers:

**Foundational templates** ship a single low-level platform resource
that other templates depend on. Apply these first to any project that
doesn't already have the equivalent resource.

| Template | Provides |
|---|---|
| `compute` | `karpenter/karpenter` (updates if present) and `kubernetes_node_pool/nodepool` |
| `cert-manager` | `cert_manager/cert-manager` for TLS issuance |
| `gateway-api-crd` | `gateway_api_crd/gateway-api-crd` for Gateway API CRDs |

**Leaf templates** ship a complete stack that consumes foundational
resources via their `requires:` declarations.

| Template | Consumes |
|---|---|
| `observability` | `cluster`, `nodepool` — ships prometheus + alert-rules + grafana-dashboards |
| `ingress` | `cluster`, `nodepool`, `cert-manager`, `gateway-api-crd` — ships the NGINX Gateway Fabric ingress |

Most leaves contain an internal dependency chain too (e.g. observability's
`alert-rules` and `grafana-dashboards` reference its `prometheus`).
Raptor's per-file `apply` validator only sees resources that already
exist in the target project — co-applied siblings in the same
`apply -f <dir>` batch are invisible to it. The two-stage apply pattern
below works around this honestly.

## Apply order

The end-to-end workflow that has been tested against a fresh project
(redesign-aws project type, no extra customization):

```bash
# 0. Project bootstrap provides: cluster, cloud, network (+ karpenter)

# 1. Apply compute — creates kubernetes_node_pool/nodepool, updates karpenter
raptor get bp-templates compute --save-to ./compute/
raptor apply -f ./compute/ -p PROJECT

# 2. Apply foundational add-ons (each independent of the others)
raptor get bp-templates cert-manager   --save-to ./cm/
raptor apply -f ./cm/   -p PROJECT
raptor get bp-templates gateway-api-crd --save-to ./gac/
raptor apply -f ./gac/  -p PROJECT

# 3. Apply observability in two stages (alert-rules + grafana depend on
#    prometheus, which is in the same template)
raptor get bp-templates observability --save-to ./obs/
raptor apply -f ./obs/prometheus.json -p PROJECT
raptor apply -f ./obs/alert-rules.json -f ./obs/grafana-dashboards.json -p PROJECT

# 4. Apply ingress (consumes cert-manager and gateway-api-crd)
raptor get bp-templates ingress --save-to ./ing/
raptor apply -f ./ing/ -p PROJECT
```

Resources ship `disabled: true`. After applying, enable them and trigger
a release.

## template.yaml

```yaml
name: <template-name>            # required, must match dir name
displayName: <human name>        # required
description: <one paragraph>     # required
category: <observability|network|compute|security|...>  # required
version: "1.0"                   # required, template version
tags: [list, of, tags]           # optional
maintainers:                     # optional
  - name: <name>
resources:                       # optional; if omitted, *.json sorted alphabetically
  - cert-manager.json
  - prometheus.json
requires:                        # optional but encouraged; documents externals
  - kubernetes_cluster/cluster
  - kubernetes_node_pool/nodepool
source:                          # optional; provenance for --details / -o yaml
  gitUrl: https://github.com/Facets-cloud/facets-modules-redesign.git
  gitRef: main
  path: templates/<template-name>
```

## Resource JSONs

Each `*.json` is a Facets resource definition with the shape:

```json
{
  "kind": "<intent>",
  "flavor": "<flavor>",
  "version": "<schema-version>",
  "metadata": {"name": "<resource-name>"},
  "disabled": true,
  "spec": { ... },
  "inputs": { ... }
}
```

Conventions:
- Ship with `disabled: true` so the consumer reviews before triggering a release.
- `metadata.name` matches the filename stem (`prometheus.json` →
  `metadata.name: "prometheus"`). Raptor's loader enforces this.
- `inputs` references use conventional default names (`cluster`,
  `cloud`, `network`, `nodepool`, `cert-manager`, `gateway-api-crd`) so
  externals line up with what foundational templates provide and with
  what `requires:` lists.
- For inputs that consume a Kubernetes cluster, set `output_name`
  explicitly: `"attributes"` for the generic `@facets/kubernetes-details`
  type (used by cert-manager, prometheus, grafana-dashboards,
  gateway-api-crd, the ingress module) — `"default"` (or omitted) for
  the cloud-specific `@facets/eks` type (used by karpenter,
  kubernetes_node_pool).

## Verifying resources

Before authoring a resource JSON, inspect the producing module's
`facets.yaml` in `modules/<intent>/<flavor>/<version>/facets.yaml` — the
`inputs:` block declares each input's `type:` (e.g. `@facets/eks` vs
`@facets/kubernetes-details`), and the `outputs:` block of the producer
declares which output emits which type.

For an extra check against a real control plane, fetch a known-working
resource:

```bash
FACETS_PROFILE=<profile> raptor get resource <kind>/<name> -p <project> -o json
```

…and mirror its `inputs` shape (resource_type / resource_name /
output_name).

## Consuming templates

```bash
# List
raptor get bp-templates
raptor get bp-templates -o wide                    # adds REQUIRES column
raptor get bp-templates --category observability   # filter

# Inspect metadata without saving
raptor get bp-templates observability --details
raptor get bp-templates observability --details -o yaml   # full metadata incl. source

# Download to disk (default ./bp-templates/<name>/)
raptor get bp-templates observability
raptor get bp-templates observability --save-to ./obs/
raptor get bp-templates observability --include-metadata   # also write template.yaml

# Print to stdout instead of saving (pipe-friendly)
raptor get bp-templates observability -o json
```

Override the upstream fetch with a local checkout (useful when
iterating on templates locally before opening a PR):

```bash
# Flag form
raptor get bp-templates --templates-dir /path/to/facets-modules-redesign/templates

# Env form (composable with scripts)
export FACETS_TEMPLATES_DIR=/path/to/facets-modules-redesign/templates
raptor get bp-templates
```

GitHub's unauthenticated rate limit is 60/hr per IP. Set
`GITHUB_TOKEN` or `GH_TOKEN` to lift it to 5000/hr if needed.

## After fetching

`raptor get bp-templates` is fetch-only — it does not apply. See
`raptor apply --help` for the applying half. Resources ship
`disabled: true`, so review them and enable selectively (or via a
per-environment override) before triggering a release.
