# Legacy central-module migration — design

**Status:** approved design, pre-implementation
**Date:** 2026-07-09
**Task:** flow `legacy-module-migration`

## What

A deterministic pipeline that moves a Facets project off the **old central-module
architecture** — modules baked into `facets-iac` and identified by `module.json` — onto
**new-style registry modules** identified by `facets.yaml`, via a **zero-change import
into a new project**. No `terraform apply` against live infrastructure; the import plan
must be `0 to change, 0 to destroy`, nothing `must be replaced`.

Two deliverables:

1. A **script** (the pipeline below), replayable and idempotent.
2. A **mapping table** — legacy `(intent, flavor, version)` → new-style module — that
   accretes one project at a time. Not built up front.

## Why

Legacy modules are not terraform modules. They are *fragments* the IaC engine completes
at generate time. `generate.py::_copy_files()` injects three template files into every
module whose `module_source == "local"`:

```python
# capillary-cloud-tf/tfmain/scripts/generate.py:217
if (not data["TESTING"]) and (self.module_source == "local"):
    shutil.copy("../tfmain/templates/variables.tf",    self.module_path)
    shutil.copy("../tfmain/templates/outputs_gen.tf",  self.module_path)
    shutil.copy("../tfmain/templates/resources_gen.tf", self.module_path)   # unless provides == "environment"
```

A registry module ships those itself. That injection *is* the "old posture."

## The predicate — what "old identification" means

`is_old`, read from `module.json`, gated by the `PRE_ALPHA` env var (default on):

```python
# generate.py:182
self.is_old = module_json.get("is_old", False) and data["PRE_ALPHA"]

# generate.py:305 — the terraform module address key
if meta.is_old:  key = meta.module_name + "_" + facets_json.name   # module_name = DIRECTORY name
else:            key = meta.provides    + "_" + facets_json.name   # provides    = intent
```

So the terraform address differs by flag:

```
  is_old = true    module.level2.module.<directory_name>_<resource_name>
  is_old = false   module.level2.module.<intent>_<resource_name>
```

**Migration always changes the address.** That is the definition of the migration, and
the translation is deterministic: `directory_name → provides`, both read from
`module.json`. Because the target is a fresh project with fresh state, import-by-
provider-ID resolves it. Flavor and version never enter the address, so renaming the
flavor is free.

### Scope, measured

| | count |
|---|---|
| `module.json` files in `capillary-cloud-tf/modules/` | 238 |
| of those, `is_old: true` | **9** |
| of those, `is_old: false` (already migrated in-repo) | 15 |
| distinct intents in scope (`helm`, `ingress`, `kubernetes_node_pool`, `postgres`, `redis`) | **5** |
| in-scope modules missing a `facets.yaml` | 0 |

The nine:

| module path | address key | intent | flavors | v |
|---|---|---|---|---|
| `helm_simple` | `helm_simple` | helm | helm_simple, default, k8s | 0.1 |
| `aws_alb_controller` | `aws_alb_controller` | ingress | alb, aws_alb | 0.1 |
| `gcp_alb` | `gcp_alb` | ingress | alb, gcp_alb | 0.1 |
| `nginx_ingress_controller` | `nginx_ingress_controller` | ingress | nlb_nginx, nginx_ingress_controller | 0.1 |
| `nginx_ingress_controller_gcp` | `nginx_ingress_controller_gcp` | ingress | nlb_nginx, nginx_ingress_controller | 0.1 |
| `2_deprecated/nginx_ingress_controller` | `nginx_ingress_controller` | ingress | nginx_ingress_controller | 0.01 |
| `gke_node_pool` | `gke_node_pool` | kubernetes_node_pool | default, gke_node_pool | 0.1 |
| `cloudsql_postgres` | `cloudsql_postgres` | postgres | default, cloudsql_postgres, cloudsql | 0.1 |
| `memorystore` | `memorystore` | redis | memorystore | 0.1 |

### Why not map onto the v3 catalog

Measured overlap between the legacy catalog and `facets-v3-modules` +
`facets-modules-redesign`:

```
legacy (non-deprecated):   97 intents  /  171 (intent, flavor) pairs
v3 + redesign union:       67 intents
intent-level overlap:      30
(intent, flavor) EXACT:     2     karpenter/default, service/k8s
legacy intents with no counterpart at all:  67
```

The v3 catalog is a *different* catalog, not a newer version of this one. Reuse is the
exception, authored per project on demand — never the default.

### Why the in-repo precedent is not the answer

Fifteen modules carry `is_old: false`. They were migrated by adding a sibling that bumps
the **version** and keeps the **flavor** (`memorystore` → `memorystore_redis_alpha` @
0.2; `gcp_alb` → `gcp_alb/0.2`). Two reasons this is only half the job:

- `memorystore/main.tf` and `memorystore_redis_alpha/main.tf` **differ**. Those were
  rewrites, not byte-identical rewraps, so they carry no zero-diff guarantee.
- They remain `module_source == "local"`. They solved *addressing*; they never touched
  *registration*.

## Design

```
                     ┌───────────── per project, on encounter ─────────────┐
                     │                                                      │
 deploymentcontext ──┤ ① SCAN    resources[].matched == false               │
 (project + env)     │           resolve → module.json, filter is_old       │
                     │           ⇒ legacy-manifest.json                     │
                     │                                                      │
 legacy tfstate ─────┤ ② JOIN    module.level2.module.<dirname>_<name>      │
 (backend, ws=       │           → provider-native id + live attributes     │
  CLUSTER_ID)        │           cross-check state ⋈ blueprint              │
 blueprint JSONs ────┤           ⇒ FAIL LOUD on any disagreement            │
                     │                                                      │
                     │ ③ MAP     mapping.yaml — accretes, checked in        │
                     │           (intent, flavor, version) → strategy       │
                     │             reuse-v3   | rewrap-old-posture (default)│
                     │           reuse-v3 auto-demotes to rewrap if its     │
                     │           plan is not 0-diff. The gate decides.      │
                     │                                                      │
                     │ ④ REWRAP  main.tf, locals.tf → byte-identical        │
                     │           templates/{variables,outputs_gen,          │
                     │             resources_gen}.tf → materialized         │
                     │           module.json → facets.yaml                  │
                     │                                                      │
                     │ ⑤ EMIT    resource docs (flavor + advanced rewritten)│
                     │           imports.tf (new addr ← id from state)      │
                     │                                                      │
                     │ ⑥ GATE    plan-only custom release                   │
                     │           0 change / 0 destroy / 0 replace           │
                     └──────────────────────────────────────────────────────┘
```

Stages ①②④⑤ are deterministic and scripted. ③ is the only place human judgment enters,
and its output is a checked-in file that grows monotonically across projects. ⑥ is the
existing `praxis-zero-change-import` gate, unmodified.

### ① SCAN — detect

Input: `deploymentcontext.json` for the project + env.

A resource is legacy when `resources[<path>].matched == false`, which sends `generate.py`
down the local-scan fallback. Resolve each to a `module.json` directory by
`(intent, flavor, version)` using the engine's own matching rule, then keep only those
with `is_old: true`.

Output `legacy-manifest.json`, one record per resource:

```json
{
  "kind": "redis", "name": "cache", "flavor": "memorystore", "version": "0.1",
  "legacy_module_dir": "capillary-cloud-tf/modules/memorystore",
  "address_key_old": "memorystore_cache",
  "address_key_new": "redis_cache"
}
```

### ② JOIN — cross-check state against blueprint

State is the authority for provider IDs and live attribute values. The blueprint is the
authority for authoring intent (`kind`, `flavor`, `version`, `spec`). **Disagreement is a
hard failure, never a silent reconciliation.**

Fail loudly on:

- a resource in state with no blueprint doc,
- a blueprint doc with no state entry,
- a spec value that contradicts the live attribute it maps to.

The third catches the `cloud_tasks` class of bug from the existing skill — a blueprint
carrying `max_attempts=2` against a live queue at `6`.

### ③ MAP — the accreting table

`mapping.yaml`, checked in, one entry per legacy `(intent, flavor, version)`:

```yaml
- legacy:  { intent: redis, flavor: memorystore, version: "0.1" }
  target:  { intent: redis, flavor: memorystore_legacy, version: "0.1" }
  strategy: rewrap-old-posture
  source_dir: capillary-cloud-tf/modules/memorystore
  first_seen_project: capillarycloud
```

`strategy` is `rewrap-old-posture` by default. `reuse-v3` is opt-in per entry and
**auto-demotes to rewrap** if its gate plan is not 0-diff. The gate decides, not the
author.

### ④ REWRAP — produce the old-posture module

Mechanical, from the legacy module directory:

- `main.tf`, `locals.tf`, `outputs.tf` → copied **byte-identical**. Never edited.
- `templates/variables.tf`, `templates/outputs_gen.tf`, `templates/resources_gen.tf` →
  materialized into the module. (`resources_gen.tf` is skipped when `provides ==
  "environment"`, matching `generate.py`.)
- `module.json` → `facets.yaml`:

| `module.json` | `facets.yaml` |
|---|---|
| `provides` | `intent` (when kind != configuration) |
| `provides` | `for` (when kind == configuration) |
| `flavors[]` | `flavor` — **one module per flavor the project actually uses** |
| `version` | `version` |
| `supported_clouds` | `clouds` |
| `inputs` | `inputs` |
| `input_type` | instance \| config |
| `lifecycle` | *(no equivalent — engine-side)* |

Because terraform is copied verbatim, the resource addresses inside the module and every
attribute it emits are identical by construction. The import is 0-diff by construction,
not by verification. The gate then confirms it.

**Flavor rename.** A registry module cannot be published at an `(intent, flavor)` that
collides with a system module. The rewrapped flavor is suffixed `_legacy`
(`memorystore` → `memorystore_legacy`) and output types are namespaced `@legacy/*`
rather than `@outputs/*` or `@facets/*`.

### ⑤ EMIT — docs and imports

The resource doc gets **two** coordinated edits, not one:

```yaml
flavor:   memorystore  ->  memorystore_legacy
advanced:
  memorystore: {...}   ->  memorystore_legacy: {...}
```

The second is mandatory. `main.tf.mustache` reads the advanced block *by flavor key*:

```hcl
advanced = lookup(lookup(local.input_{{key}}, "advanced", {}), "{{flavor}}", {})
```

Rename the flavor without renaming the `advanced` key and the block resolves to `{}` —
a silent config drop. The script rewrites both, and asserts that no `advanced` key
remains that matches a pre-rename flavor.

`imports.tf` maps the new address to the provider-native ID pulled from legacy state:

```hcl
import {
  to = module.level2.module.redis_cache.google_redis_instance.this
  id = "projects/<p>/locations/<l>/instances/cache"
}
```

### ⑥ GATE — unchanged

Plan-only custom release. Clean means `0 to change, 0 to destroy`, nothing
`must be replaced`. The only benign diffs are `scratch_string.release_metadata` and
additive `Changes to Outputs`. **Fix the module, never loosen the gate.**

## Testing

TDD, per repo convention.

- **①** golden `deploymentcontext.json` fixtures → asserted `legacy-manifest.json`.
  Includes a matched-resource fixture that must be *excluded*, and an `is_old: false`
  fixture that must be excluded.
- **②** a state/blueprint pair that agrees (passes) and three that disagree in each of
  the three ways (each must fail, with the disagreement named).
- **④** rewrap `memorystore`, assert `main.tf` is byte-identical to source, assert the
  three templates are present, assert the generated `facets.yaml` round-trips to the
  same `(intent, flavor, version, clouds)` as `module.json`.
- **⑤** a doc carrying `advanced.memorystore` → assert output carries
  `advanced.memorystore_legacy` and no `advanced.memorystore`. A doc with no `advanced`
  block → assert no key is invented.
- **⑥** integration, against the pilot project, plan-only.

## Pilot

The **capillarycloud project on the root CP**. Its `is_old` resource set drives the
first `mapping.yaml` entries. Nothing is authored for a module the pilot does not use.

## Out of scope

- The 46 modules under `2_deprecated/` — except `2_deprecated/nginx_ingress_controller`,
  which is `is_old: true` and therefore in scope if the pilot uses it.
- Modernizing rewrapped modules onto canonical v3 contracts. That is a separate,
  later, per-module pass, each gated on its own 0-diff plan.
- Any `terraform apply` against live infrastructure beyond writing imports to state.
- Changing `PRE_ALPHA`. Flipping it would re-address every legacy resource in place.

## Open questions

- Does the CP registry permit publishing at `version: "0.1"`, or is there a floor? The
  rewrap keeps the legacy version verbatim; if the registry rejects it, we bump and the
  doc's `version` field joins `flavor` and `advanced` in the rewrite set.
- `2_deprecated/nginx_ingress_controller` and `nginx_ingress_controller` share the
  address key `nginx_ingress_controller` at different versions (0.01 / 0.1). If the
  pilot uses both, the manifest must disambiguate on version, not on address key alone.
- Versioned legacy directories (`gcp_alb/0.2`) would yield `module_name == "0.2"` under
  `_module_name()`. None are currently `is_old: true`, so this is latent. The scanner
  should assert it never encounters one rather than silently emit `0.2_<resource>`.
