# Blueprint Templates

This directory holds curated bundles of Facets blueprint resources. Each
subdirectory is one template. Raptor's `get bp-templates` command discovers
and downloads them from a local checkout of this repository.

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
maintainers:
  - name: <name>
    url: <url>
resources:                       # optional; if omitted, *.json sorted alphabetically
  - cert-manager.json
  - prometheus.json
requires:                        # optional; documents externals
  - kubernetes_cluster/cluster
  - cloud_account/cloud
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
  `network`) so external requirements line up with what `requires:` lists.

## Verifying resources

Before authoring a resource JSON, inspect the corresponding module's schema:

```bash
FACETS_PROFILE=<profile> raptor describe module <KIND>/<FLAVOR>/<VERSION>
```

This shows the exact required inputs and spec fields. Do not invent fields.

## Consuming templates

```bash
# Point raptor at this directory
raptor get bp-templates --templates-dir <path-to-this-repo>/templates

# Or set an env var
export FACETS_TEMPLATES_DIR=<path-to-this-repo>/templates
raptor get bp-templates

# Or copy/link to /tmp/facets-templates (raptor's default)
ln -s <path-to-this-repo>/templates /tmp/facets-templates
raptor get bp-templates
```

After downloading, apply with the standard pipeline:

```bash
raptor get bp-templates observability --save-to ./obs/
raptor apply -f ./obs/ -p PROJECT --dry-run
raptor apply -f ./obs/ -p PROJECT -m "Bootstrap observability"
```
