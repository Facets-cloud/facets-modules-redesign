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

| Template | Provides | Cloud |
|---|---|---|
| `compute` | `karpenter/karpenter` (updates if present) and `kubernetes_node_pool/nodepool` | AWS-only (uses `karpenter/default/1.0` and `kubernetes_node_pool/karpenter/1.0`) |
| `cert-manager` | `cert_manager/cert-manager` for TLS issuance | cloud-agnostic |
| `gateway-api-crd` | `gateway_api_crd/gateway-api-crd` for Gateway API CRDs | cloud-agnostic |

**Leaf templates** ship a complete stack that consumes foundational
resources via their `requires:` declarations.

| Template | Consumes | Cloud |
|---|---|---|
| `observability` | `cluster`, `nodepool` — ships prometheus + alert-rules + grafana-dashboards | cloud-agnostic |
| `ingress` | `cluster`, `nodepool`, `cert-manager`, `gateway-api-crd` — ships the NGINX Gateway Fabric ingress on AWS (`nginx_gateway_fabric_aws/1.0`) | AWS-only |

GCP / Azure / OVH variants of `compute` and `ingress` will land as
separate templates (e.g. `compute-gcp`, `ingress-azure`) following the
same pattern.

Most leaves contain an internal dependency chain too (e.g. observability's
`alert-rules` and `grafana-dashboards` reference its `prometheus`).
Raptor's per-file `apply` validator only sees resources that already
exist in the target project — co-applied siblings in the same
`apply -f <dir>` batch are invisible to it. The two-stage apply pattern
below works around this honestly.

## Apply order

The end-to-end workflow that has been tested against a fresh project
(`redesign-aws` project type, no extra customization). Other project
types may name resources differently — see "Adapting to a different
bootstrap" below.

```bash
# 0. Project bootstrap provides: cluster, cloud, network (+ karpenter)

# 1. Apply compute — creates kubernetes_node_pool/nodepool, updates karpenter.
#    If your project's bootstrap doesn't already include karpenter, apply
#    karpenter.json first (release), then nodepool.json — kubernetes-node-pool
#    references karpenter and the validator can't see co-applied siblings.
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

### Adapting to a different bootstrap

These templates assume conventional resource names: `cluster` (for
`kubernetes_cluster`), `nodepool`, `cloud`, `network`, `cert-manager`,
`gateway-api-crd`, `prometheus`. If your project's bootstrap uses
different names, edit the downloaded JSONs' `inputs.<key>.resource_name`
values before applying — `raptor get bp-templates <name>` writes them to
disk first, so the consumer (or AI agent) can rewrite refs in place.

## template.yaml

```yaml
name: <template-name>            # required, must match dir name
displayName: <human name>        # required
description: <one paragraph>     # required
category: <observability|network|compute|security|...>  # required
version: "1.0"                   # required; bump on backwards-incompatible changes
                                 # (resource removed, requires: tightened, etc.)
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
  explicitly. The right value depends on what the consuming module's
  `kubernetes_details` (or equivalent) input declares as its `type:`:
    - `@facets/kubernetes-details` (cloud-agnostic) → `output_name: "attributes"`
      — used by cert-manager, prometheus, grafana-dashboards, gateway-api-crd.
    - `@facets/eks` (or `@facets/gke` / `@facets/azure_aks`, cloud-specific) →
      `output_name: "default"` (or omitted) — used by karpenter,
      kubernetes_node_pool, **and the AWS ingress flavor**
      (`nginx_gateway_fabric_aws`). Always check the producing module's
      `facets.yaml` to be sure.
- Input KEY names are dictated by the consuming module's `facets.yaml`
  and aren't always uniform — e.g. most modules call the Kubernetes
  cluster input `kubernetes_details`, but `alert_rules/prometheus`
  calls it `kubernetes_cluster`. Mirror what the module declares
  rather than guessing.

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
