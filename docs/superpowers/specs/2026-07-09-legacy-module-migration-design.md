# Legacy central-module migration — design

**Status:** approved design, pre-implementation
**Date:** 2026-07-09 (recalibrated 2026-07-10)
**Task:** flow `legacy-module-migration`
**Pilot:** project `capillary-cloud`, environment `facetsdemo`, on `root.console.facets.cloud`

## What

A deterministic pipeline that moves a Facets project off the **old central-module
architecture** — modules resolved from the `facets-iac` repo — onto **new-style registry
modules** identified by `facets.yaml`, via a **zero-change import into a new project** of
a new project type, `old-style`.

No `terraform apply` against live infrastructure. The import plan must be
`0 to change, 0 to destroy`, nothing `must be replaced`.

Deliverables:

1. A **script** — the pipeline below — replayable and idempotent.
2. A **`old-style` project type** (`project-type/old-style/project-type.yml`), starting
   from cloud account only, whose module list accretes.
3. A **mapping table** — legacy `(intent, flavor, version)` → rewrapped module — that
   accretes one project at a time. Not built up front.

## The predicate — what makes a module legacy

**If the module resolves out of the facets-iac repo, it is old.** Full stop. The engine
calls this `module_source == "local"`:

```python
# capillary-cloud-tf/tfmain/scripts/generate.py:217
if (not data["TESTING"]) and (self.module_source == "local"):
    shutil.copy("../tfmain/templates/variables.tf",     self.module_path)
    shutil.copy("../tfmain/templates/outputs_gen.tf",   self.module_path)
    shutil.copy("../tfmain/templates/resources_gen.tf", self.module_path)  # unless provides == "environment"
```

A legacy module is not a terraform module. It is a *fragment* the engine completes at
generate time by injecting those three files. A registry module ships them itself. That
injection **is** the "old posture," and reproducing it is what makes the rewrap safe.

**System modules are legacy too.** The 29 modules under `0_input_config/` are implicit,
one per cluster, and present in every project. They resolve `module_source == "local"`
like everything else. Do not mistake their ubiquity for having been migrated.

### `is_old` is an addressing quirk, not a filter

`is_old` does **not** decide whether a module is legacy. It decides only how the
terraform address is composed:

```python
# generate.py:182
self.is_old = module_json.get("is_old", False) and data["PRE_ALPHA"]   # PRE_ALPHA defaults on

# generate.py:305
if meta.is_old:  key = meta.module_name + "_" + name   # module_name = DIRECTORY name
else:            key = meta.provides    + "_" + name   # provides    = intent
```

```
  is_old: true    module.level2.module.<directory_name>_<resource>    address MOVES on migration
  is_old: false   module.level2.module.<intent>_<resource>            address STABLE
```

Both are legacy. Only the first needs an address translation, and that translation is
deterministic: `directory_name → provides`, both read from `module.json`. Flavor and
version never enter the address, so renaming the flavor is free.

### Scope, measured

```
all module.json in capillary-cloud-tf/modules/     238      (all module_source == "local")
  ├─ 2_deprecated/                                  46      out of scope unless a project uses one
  └─ in scope                                      192
       ├─ 1_input_instance/   127   explicit, per resource
       ├─ <top-level>          36
       └─ 0_input_config/      29   implicit system modules — legacy, one per cluster

  addressing within the 192:
    is_old: false → <intent>_<resource>      184   address stable
    is_old: true  → <dirname>_<resource>       8   address moves
```

The 192 is the *universe*. Nothing is authored from it up front. A module is rewrapped
only when a project being adopted actually instantiates it.

### The pilot's actual demand

`capillary-cloud` has 97 blueprint resources. Classified against the module tree:

| | count |
|---|---|
| resources resolving to a facets-iac module (legacy) | **74** |
| distinct `(intent, flavor)` pairs to rewrap | **24** |
| resources whose terraform address moves (`is_old`) | **10** — all `helm`, from `helm_simple` |
| resources not resolving (registry, or `configuration` kind) | 23 |

The address moves are confined to one module directory:

```
module.level2.module.helm_simple_tekton   ->  module.level2.module.helm_tekton
module.level2.module.helm_simple_trivy    ->  module.level2.module.helm_trivy
...  (10 resources, intent `helm`, flavors default / helm_simple / k8s)
```

The 23 unresolved include `configuration` kind (7) — the implicit system modules, which
resolve by a different code path — plus genuinely-registry modules such as
`image_pull_secret_injector/default` and `gateway_api_crd/legacy`. The scanner must
classify these explicitly rather than leave them in a residual bucket.

### Can an existing redesign module be reused? — evaluated, not assumed

Zero-diff import requires the *terraform resource addresses inside the module* to match.
So the test is not "does an `s3` module exist" but "does it declare the same
`resource "<type>" "<name>"` and `module "<name>"` set?" Applied to the pilot's 19
distinct legacy module directories (excluding `actions.tf`, which holds Tekton
operational actions and is identical boilerplate everywhere):

| verdict | count |
|---|---|
| **must be written as a rewrap** | **18 / 19** |
| address set matches an existing module | **1** — `helm_simple` vs `common/helm/k8s_standard/1.0`, both `helm_release.external_helm_charts` |

Of the 18: seven have **no new-style intent at all** (`alert_group`, `dynamodb`,
`grafana_dashboard`, `iam_policy`, `log_collector`, `loki_alerting_rules`,
`snapshot_schedule`, `tcp_lb`); eleven have an intent whose module declares a **different
address set**.

Even the single match is not a free reuse. The bodies differ — legacy carries
`prevent_destroy`, redesign carries `prometheus_id`, and the `values`/`set` handling
diverges. It is a *candidate*, resolved by the gate, not by inspection. This is exactly
why `strategy: reuse-v3` auto-demotes to `rewrap-old-posture` on a non-clean plan.

Coarser context: across the whole catalog, only 2 of 171 legacy `(intent, flavor)` pairs
exist in `facets-v3-modules` + `facets-modules-redesign`. The v3 catalog is a *different*
catalog, not a newer version of this one. **Reuse is the exception; assume you are
writing a rewrap.**

### Vendoring — legacy modules are not self-contained

Legacy modules reach outside their own directory with relative sources:

```hcl
# 1_input_instance/aws_iam_role/main.tf
module "aws_iam_role_name" { source = "../../3_utility/name" }
module "iam_eks_role"      { source = "../../3_utility/aws_irsa/iam-role-for-service-accounts-eks" }
```

That works because the engine runs them *in place* inside the repo tree. A registry
module is packaged standalone, so every `../` source breaks on upload. The pilot's 19
directories reference 15 distinct external targets:

```
  ../../3_utility/name                                     x5     ../../3_utility/application            x1
  ../3_utility/name                                        x4     ../../3_utility/legacy_azure_aks       x1
  ../../3_utility/any-k8s-resource                         x2     ../../3_utility/gcp_workload-identity/…x1
  ../../3_utility/aws_irsa/iam-role-for-service-accounts-eks  x1  ../../../3_utility/{pvc,password,…}    x5
  ../../log_collector/0.2                                  x1  ← a legacy module depending on another
  ../../../1_input_instance/snapshot_schedule              x1  ← and another
```

`3_utility/` holds 22 shared sub-modules. **The rewrap must vendor the transitive closure
of `../` sources into the module directory and rewrite each `source` to a local path.**
Vendoring changes the `source` string but not the module block's *name*, so terraform
addresses are preserved — which is what the gate cares about. Two of the targets are
other legacy modules (`log_collector/0.2`, `1_input_instance/snapshot_schedule`), so the
closure is a graph walk, not a single hop.

## Design

```
                     ┌───────────── per project, on encounter ─────────────┐
 blueprint +         │ ① SCAN    every resource resolving module_source=   │
 module tree ────────┤           "local"  ⇒ legacy-manifest.json           │
                     │           tag each with is_old → address translation │
                     │                                                      │
 legacy tfstate ─────┤ ② JOIN    module.level2.module.<key>_<name>          │
 (backend, ws=       │           → provider-native id + live attributes     │
  CLUSTER_ID)        │           cross-check state ⋈ blueprint              │
                     │           ⇒ FAIL LOUD on any disagreement            │
                     │                                                      │
                     │ ③ MAP     mapping.yaml — accretes, checked in        │
                     │           (intent, flavor, version) → rewrapped id   │
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
and its output is a checked-in file that grows monotonically. ⑥ is the existing
`praxis-zero-change-import` gate, unmodified: **fix the module, never loosen the gate.**

### The scripts

```
 bin/
 ├── scan-legacy.py       ① blueprint + module tree  ->  legacy-manifest.json
 │                           classifies every resource: legacy | registry | configuration
 │                           tags is_old, computes old/new terraform address
 │
 ├── join-state.py        ② legacy tfstate  ⋈  manifest  ->  enriched manifest
 │                           attaches provider-native id + live attributes
 │                           FAILS LOUD on: state-without-doc, doc-without-state,
 │                                          spec value contradicting live attribute
 │
 ├── rewrap-module.py     ④ legacy module dir  ->  publishable module dir
 │                           copy main/locals/outputs .tf byte-identical
 │                           materialize the 3 engine-injected templates
 │                           vendor transitive ../ closure, rewrite source paths
 │                           synthesize facets.yaml (flavor + _legacy, @legacy/* outputs)
 │
 ├── emit-docs.py         ⑤ enriched manifest  ->  resource docs
 │                           rewrites flavor AND advanced.<flavor> in lockstep
 │                           env-specific values -> environment override, not blueprint
 │
 ├── emit-imports.py      ⑤ enriched manifest  ->  imports.tf
 │                           new address  <-  provider-native id
 │
 ├── carry-vars.sh        variables + secrets, source project -> target project, per env
 │                           pipes values; never prints them; asserts key-set equality
 │
 └── gate.sh              ⑥ plan-only custom release -> poll status -> grep verdict
                             clean iff: 0 to change, 0 to destroy, nothing must be replaced
                             benign: scratch_string.release_metadata, additive outputs

 mapping.yaml             ③ the accreting table. The only human-authored artifact.
```

`scan-legacy.py`, `join-state.py`, `rewrap-module.py`, `emit-docs.py` and
`emit-imports.py` are pure functions of their inputs: same blueprint + same state ⇒ same
output, byte for byte. They are re-runnable at any point. `gate.sh` and `carry-vars.sh`
touch the control plane; `gate.sh` mutates nothing.

### ④ REWRAP — producing the old-posture module

Mechanical, from the legacy module directory:

- `main.tf`, `locals.tf`, `outputs.tf` → copied **byte-identical**. Never edited.
- `templates/variables.tf`, `templates/outputs_gen.tf`, `templates/resources_gen.tf` →
  materialized into the module (`resources_gen.tf` skipped when `provides ==
  "environment"`, matching `generate.py`).
- transitive `../` source closure → **vendored** into the module, each `source` rewritten
  to a local path. Module block *names* are never changed, so addresses survive.
- `module.json` → `facets.yaml`:

| `module.json` | `facets.yaml` |
|---|---|
| `provides` | `intent` (kind != configuration) |
| `provides` | `for` (kind == configuration) |
| `flavors[]` | `flavor` — one module per flavor **the project actually uses** |
| `version` | `version` |
| `supported_clouds` | `clouds` |
| `inputs` | `inputs` |
| `lifecycle` | *(no equivalent — engine-side)* |

Because terraform is copied verbatim, resource addresses inside the module and every
attribute it emits are identical by construction. The import is 0-diff *by construction*,
not by verification; the gate then confirms it.

**Flavor rename.** A registry module cannot be published at an `(intent, flavor)` that
collides with a system module. Every rewrapped flavor is suffixed `_legacy`
(`memorystore` → `memorystore_legacy`), and output types are namespaced `@legacy/*`
rather than `@outputs/*` or `@facets/*`.

### ⑤ EMIT — the coordinated doc edit

Each resource doc takes **two** edits, not one:

```yaml
flavor:   k8s          ->  k8s_legacy
advanced:
  k8s: {...}           ->  k8s_legacy: {...}
```

The second is mandatory. `main.tf.mustache` reads the advanced block *by flavor key*:

```hcl
advanced = lookup(lookup(local.input_{{key}}, "advanced", {}), "{{flavor}}", {})
```

Rename the flavor without renaming the `advanced` key and the block silently resolves to
`{}` — a config drop that may not even surface as a plan diff. The script rewrites both,
then asserts no `advanced` key remains matching a pre-rename flavor.

## Creating the new project

The target is a new project of type `old-style`, adopted one environment at a time.

### Step 0 — publish the project type

`project-type/old-style/project-type.yml` starts from cloud account only. No
`baseTemplatePath`: a project of this type begins with nothing but a cloud account, and
every other resource arrives via import.

### Step 1 — create the project

```bash
raptor create project capillary-cloud-v2 --project-type old-style --clouds AWS
```

### Step 2 — rewrap and publish the pilot's 24 modules

Driven by `mapping.yaml`, seeded from the pilot's demand. Each module is validated
before upload:

```bash
raptor create iac-module -f <module-path> --dry-run   # never --skip-validation
raptor create iac-module -f <module-path>
```

### Step 3 — wire the cloud account, deploy it alone

Deploy `cloud_account` via a targeted release so its outputs (account id, region,
credentials) populate. This is a no-op deploy — data sources and outputs only, zero cloud
infrastructure. The environment must be RUNNING; a stopped env cannot release.

### Step 4 — own the first environment: `facetsdemo`

`capillary-cloud` has **23 environments**, and each one is a customer's control plane
(`moveinsync`, `vymo-facets-cp`, `treebo-cp`, `commerceiq-cp`, `fourkites-cp`, …). Three
are `DESTROY_FAILED`, two are `STOPPED`.

`facetsdemo` is the pilot: it is RUNNING, it is a demo control plane rather than a
customer's, and a mistake there costs nothing. `root` is excluded on purpose — it is the
control plane we are operating *from*.

Per environment, in order:

1. **Create the environment** in the new project, matching cloud and region.
2. **Carry variables and secrets.** `capillary-cloud` has 68 variables/secrets, one of
   them global. Secrets are per-environment and have no stack default.
   `raptor get variable --show-secrets` requires `VIEW_SECRETS`. **Values must never
   enter an agent transcript or a log.** The script pipes them directly from source to
   destination and asserts count parity plus per-key presence — never values.
3. **Emit resource docs** for that environment, with env-specific values placed in the
   environment override, not the blueprint. Region, zones, names, allowlists, webhook
   URLs are override material; the blueprint stays portable.
4. **Emit `imports.tf`**, mapping each new address to the provider-native ID pulled from
   that environment's legacy state.
5. **Gate**: plan-only custom release. `0 to change, 0 to destroy`, nothing
   `must be replaced`.
6. **Import**: apply the import blocks only after a clean gate. This writes to terraform
   state; it does not touch cloud infrastructure.
7. **Re-gate**: plan again, confirm still clean.

Only after `facetsdemo` completes all seven does a second environment begin. Environments
are independent state; the blueprint is shared, so a blueprint change made for env N must
be re-gated against every already-imported environment.

## Testing

TDD, per repo convention.

- **①** golden blueprint + module-tree fixtures → asserted `legacy-manifest.json`. Must
  include an `is_old: true` case (address moves), an `is_old: false` case (address
  stable), a `configuration`-kind system module, and a genuinely-registry resource that
  must be excluded.
- **②** a state/blueprint pair that agrees (passes) and three that disagree — resource in
  state with no doc, doc with no state, spec value contradicting the live attribute. Each
  must fail, naming the disagreement.
- **④** rewrap `helm_simple`; assert `main.tf` byte-identical to source, the three
  templates present, and the generated `facets.yaml` round-trips to the same
  `(intent, flavor, version, clouds)` as `module.json`.
- **⑤** a doc carrying `advanced.k8s` → assert output carries `advanced.k8s_legacy` and
  no `advanced.k8s`. A doc with no `advanced` block → assert no key is invented.
- **variables/secrets** → assert count parity and key-set equality without reading values.
- **⑥** integration, against `facetsdemo`, plan-only.

## Out of scope

- The 46 modules under `2_deprecated/`, unless the pilot instantiates one.
- Modernizing rewrapped modules onto canonical v3 contracts — a separate, later,
  per-module pass, each gated on its own 0-diff plan.
- Any `terraform apply` against live infrastructure beyond writing imports to state.
- Changing `PRE_ALPHA`. Flipping it would re-address every `is_old` resource in place.

## Open questions

- Does the CP registry permit publishing at `version: "0.1"`, or is there a floor? The
  rewrap keeps the legacy version verbatim; a floor would add `version` to the doc
  rewrite set alongside `flavor` and `advanced`.
- The 7 `configuration`-kind resources resolve through the implicit-module path
  (`0_input_config/`), not the explicit one. Their rewrap uses `for:` rather than
  `intent:` in `facets.yaml`. Confirm the registry accepts a config-kind module.
- `2_deprecated/nginx_ingress_controller` and `nginx_ingress_controller` share the
  address key `nginx_ingress_controller` at versions 0.01 and 0.1. Not in the pilot's
  demand, but the manifest must disambiguate on version, not address key alone.
- Versioned legacy directories (`gcp_alb/0.2`) would yield `module_name == "0.2"` under
  `_module_name()`. None are currently `is_old: true`, so this is latent. The scanner
  should assert it never encounters one rather than silently emit `0.2_<resource>`.
