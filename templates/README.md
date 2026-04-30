# Blueprint Templates

This directory holds curated bundles of Facets blueprint resources. Each
subdirectory is one template. Raptor's `get bp-templates` command auto-fetches
this repository on first use and reads templates from it — consumers do **not**
need to clone the repo manually.

## Layout

```
templates/
├── README.md                  (this file)
└── <template-name>/
    ├── template.yaml          (metadata; required)
    └── *.json                 (resource JSONs; one per file)
```

## template.yaml

```yaml
name: <template-name>            # required, must match dir name
displayName: <human name>        # required
description: <one paragraph>     # required
category: <observability|network|compute|databases|configs|...>  # required
version: "1.0"                   # required, template version
tags: [list, of, tags]           # optional
maintainers:                     # optional
  - name: <name>
resources:                       # optional; if omitted, *.json sorted alphabetically
  - cert-manager.json
  - prometheus.json
requires:                        # optional but encouraged; documents externals
  - kubernetes_cluster/cluster
  - cloud_account/cloud
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
  `metadata.name: "prometheus"`).
- `inputs` references use conventional default names (`cluster`, `cloud`,
  `network`, `nodepool`, `gateway-crd`) so external requirements line up with
  what `requires:` lists.
- For inputs that consume a Kubernetes cluster, set `output_name` explicitly:
  `attributes` for the generic `@facets/kubernetes-details` type (used by
  cert-manager, prometheus, grafana_dashboards, gateway_api_crd, the ingress
  module) — `default` (or omitted) for the cloud-specific `@facets/eks` type
  (used by karpenter, kubernetes_node_pool).
- **Important:** raptor's per-file `apply` validator only sees resources that
  already exist in the target project — co-applied siblings in the same
  `apply -f <dir>` batch are invisible to it. Author intra-template inputs
  to point at resources expected to already exist in the consumer's project,
  and document those in `requires:`. Don't try to make a template fully
  self-bootstrapping in one apply call.

## Verifying resources

Before authoring a resource JSON, inspect the producing module's `facets.yaml`
in `modules/<intent>/<flavor>/<version>/facets.yaml` — the `inputs:` block
declares each input's `type:` (e.g., `@facets/eks` vs
`@facets/kubernetes-details`), and the `outputs:` block of the producer
declares which output emits which type.

For an extra check against a real control plane, fetch a known-working
resource:

```bash
FACETS_PROFILE=<profile> raptor get resource <kind>/<name> -p <project> -o json
```

…and mirror its `inputs` shape (resource_type / resource_name / output_name).

## Consuming templates

The default flow — no flags, no env, no manual clone:

```bash
# Auto-fetches https://github.com/Facets-cloud/facets-modules-redesign.git@main
# into /tmp/facets-modules-redesign/ on first call. Reuses the clone on
# subsequent calls. Pass --refresh to re-clone.
raptor get bp-templates
raptor get bp-templates -o wide                    # also show REQUIRES column
raptor get bp-templates --category observability   # filter
raptor get bp-templates observability --details    # metadata only
raptor get bp-templates observability --details -o yaml   # full metadata incl. source
```

Override the auto-fetch with a local checkout (useful when iterating on
templates locally before opening a PR):

```bash
# Flag form
raptor get bp-templates --templates-dir /path/to/facets-modules-redesign/templates

# Env form (composable with scripts)
export FACETS_TEMPLATES_DIR=/path/to/facets-modules-redesign/templates
raptor get bp-templates
```

Force a re-clone of the upstream:

```bash
raptor get bp-templates --refresh
```

## Applying a template

`raptor get bp-templates` only fetches and writes resource JSONs — it does
not apply. After downloading, use the standard `raptor apply` pipeline:

```bash
# Download to ./bp-templates/<name>/ by default
raptor get bp-templates observability

# Or to a custom path
raptor get bp-templates observability --save-to ./obs/

# Validate without applying
raptor apply -f ./bp-templates/observability/ -p PROJECT --dry-run

# Apply
raptor apply -f ./bp-templates/observability/ -p PROJECT -m "Bootstrap observability"
```

Resources ship `disabled: true`. Once applied, review them in the project
and enable selectively (or via a per-environment override) before triggering
a release.
