# SOP — Adopting a legacy central-module project into an `old-style` project · `<PROJECT>` / `<ENV>`

> Instantiate per (project, environment): copy, fill every `<...>`, work top-to-bottom.
> Everything here runs through `praxis` and `raptor`. There are no scripts — which means
> **the guardrails in §6 are the only thing standing between you and a silent config drop.**
> Run them. Log new gotchas in §9.
>
> Design: `docs/superpowers/specs/2026-07-09-legacy-module-migration-design.md`
> Gate discipline: the `praxis-zero-change-import` skill. Do not restate it; obey it.

---

## 0. Context (memorize)

```
  CP                  <control-plane url>            e.g. https://root.console.facets.cloud
  Source project      <SRC_PROJECT>                  e.g. capillary-cloud
  Target project      <DST_PROJECT>                  e.g. capillary-cloud-v2   (type: old-style)
  Environment         <ENV>                          e.g. facetsdemo   (must be RUNNING)
  Cloud               <CLOUD>                        e.g. AWS
  facets-iac checkout <PATH>  branch tfdev           modules at capillary-cloud-tf/modules/
  Vars + secrets      <N>  (source project)          values NEVER enter a transcript or log
```

**The one invariant.** The import plan must be `0 to change, 0 to destroy`, nothing
`must be replaced`. Benign: `scratch_string.release_metadata`, additive
`Changes to Outputs`. If a plan wants to replace or destroy a real resource, **the module
is wrong — fix the module, never loosen the gate.**

---

## 1. Recon — classify every resource

A resource is **legacy** iff its module resolves out of the facets-iac repo
(`module_source == "local"`). Membership in the repo is the whole test. System modules
under `0_input_config/` are legacy too — their ubiquity is not evidence of migration.

```bash
raptor get resources -p <SRC_PROJECT> -o json > /tmp/<SRC_PROJECT>-resources.json
```

For each resource, find `(kind, flavor)` in the module tree:

```bash
grep -rl '"provides": *"<KIND>"' <PATH>/capillary-cloud-tf/modules/*/module.json \
                                 <PATH>/capillary-cloud-tf/modules/*/*/module.json
```

Record three buckets. **Do not leave a residual bucket** — every resource is classified:

```
  legacy        → §3 rewrap        (resolves to a module.json in facets-iac)
  registry      → carry as-is      (already a new-style module)
  configuration → §3, but `for:` not `intent:` in facets.yaml (implicit, 0_input_config)
```

Then read `is_old` for each legacy module. It does **not** decide legacy-ness; it decides
the terraform address:

```
  is_old: true   module.level2.module.<DIRECTORY_NAME>_<resource>    ← address MOVES
  is_old: false  module.level2.module.<intent>_<resource>            ← address STABLE
```

Write the address translation down per resource. You will need it in §5.

> Pilot reference (`capillary-cloud`): 97 resources → 74 legacy across 24 `(intent, flavor)`
> pairs; 10 resources move address, all `helm` from `helm_simple`.

---

## 2. Mapping table — the accreting artifact

Append to `mapping.yaml` in this repo. One entry per legacy `(intent, flavor, version)`.
It grows monotonically across projects. **This is the only file requiring judgment.**

```yaml
- legacy:  { intent: redis, flavor: memorystore, version: "0.1" }
  target:  { intent: redis, flavor: memorystore_legacy, version: "0.1" }
  strategy: rewrap-old-posture        # or: reuse-existing
  source_dir: capillary-cloud-tf/modules/memorystore
  is_old: true
  address:  { old: memorystore_<name>, new: redis_<name> }
  first_seen_project: capillary-cloud
```

**Default to `rewrap-old-posture`.** Reuse is the exception: across the whole catalog only
2 of 171 legacy `(intent, flavor)` pairs exist in `facets-v3-modules` +
`facets-modules-redesign`. Before claiming `reuse-existing`, compare the terraform
resource *address sets* — not the intent name:

```bash
grep -hE '^\s*(resource|module) "' <legacy-dir>/*.tf   | grep -v actions.tf | sort
grep -hE '^\s*(resource|module) "' <candidate-dir>/*.tf | grep -v actions.tf | sort
```

Exclude `actions.tf` — it holds `facets_tekton_action_*` operational actions, which are
identical boilerplate in every module and will fake a match. A matching address set makes
a module a *candidate*, not a reuse. **`reuse-existing` auto-demotes to
`rewrap-old-posture` the moment its gate plan is not clean.**

---

## 3. Rewrap a legacy module

Legacy modules are **fragments**, not terraform modules. `generate.py::_copy_files()`
injects three template files into every `module_source == "local"` module at generate
time. A registry module ships them itself.

For each `(intent, flavor)` in the mapping table:

**a. Copy the terraform byte-identical.** `main.tf`, `locals.tf`, `outputs.tf`,
`version.tf`, `actions.tf`. Never edit them. This is what makes the import 0-diff *by
construction* rather than by verification.

**b. Materialize the three injected templates** from
`capillary-cloud-tf/tfmain/templates/`:

```bash
cp <PATH>/capillary-cloud-tf/tfmain/templates/variables.tf    <module>/
cp <PATH>/capillary-cloud-tf/tfmain/templates/outputs_gen.tf  <module>/
cp <PATH>/capillary-cloud-tf/tfmain/templates/resources_gen.tf <module>/   # SKIP if provides == "environment"
```

**c. Vendor the transitive `../` closure.** Legacy modules reach outside their directory:

```hcl
module "aws_iam_role_name" { source = "../../3_utility/name" }
module "iam_eks_role"      { source = "../../3_utility/aws_irsa/iam-role-for-service-accounts-eks" }
```

Those work only in-tree. Copy each target into the module and rewrite `source` to a local
path. **It is a graph walk, not one hop** — `3_utility/*` modules have their own `../`
refs, and two targets are *other legacy modules* (`../../log_collector/0.2`,
`../../../1_input_instance/snapshot_schedule`). Rewriting `source` does not change a
module block's **name**, so terraform addresses survive.

**d. Synthesize `facets.yaml`** from `module.json`:

| `module.json` | `facets.yaml` |
|---|---|
| `provides` | `intent` (kind != configuration) |
| `provides` | `for` (kind == configuration) |
| `flavors[]` | `flavor` — one module per flavor **the project actually uses** |
| `version` | `version` |
| `supported_clouds` | `clouds` |
| `inputs` | `inputs` |
| `lifecycle` | *(no equivalent — engine-side)* |

Suffix the flavor `_legacy` — a registry module cannot be published at an
`(intent, flavor)` that collides with a system module. Namespace output types `@legacy/*`:

```bash
raptor create output-type @legacy/<name> -f <schema.yaml> --dry-run
raptor create output-type @legacy/<name> -f <schema.yaml>
```

**e. Validate, then upload.** Never `--skip-validation`.

```bash
raptor create iac-module -f <module-dir> --dry-run --block-remote-modules
raptor create iac-module -f <module-dir> --publish
```

`--block-remote-modules` is the machine check on step (c): it rejects any module source
that is not local. If it passes, the vendoring is complete.

If the security scan fails, retry with `--skip-security-scan` and **report the findings
to the user in a table**. Never skip silently.

---

## 4. Create the target project

Once per project, not per environment.

```bash
# a. project type (once per CP)
raptor create project-type old-style --description "Legacy central-module adoption; starts from cloud account"
raptor create resource-type-mapping old-style \
  --resource-type cloud_account/aws_provider \
  --resource-type helm/k8s_legacy \
  --resource-type s3/default_legacy            # ... one per mapping.yaml entry, as they land

# b. project
raptor create project <DST_PROJECT> --project-type old-style --clouds <CLOUD>
```

The `old-style` type has **no `baseTemplatePath`**. A project of this type begins with
nothing but a cloud account; everything else arrives by import.

---

## 5. Adopt ONE environment

Environments hold independent terraform state. The blueprint is shared. **Finish one
environment completely before starting the next**, and re-gate every already-imported
environment after any blueprint change made for a later one.

Pick the first environment on risk, not convenience. For `capillary-cloud`, each of the
23 environments is a customer's control plane; `facetsdemo` is a demo CP and is RUNNING.
`root` is excluded — it is the control plane we are operating *from*. A `STOPPED`
environment cannot release.

**a. Create it.**

```bash
raptor create environment <ENV> -p <DST_PROJECT> --release-stream <STREAM>
```

**b. Carry variables and secrets.** Secrets are per-environment and have no stack
default. Reading them requires `VIEW_SECRETS`.

> **Values must never enter a transcript, a log, or a chat message.** Pipe them. Do not
> echo them. Do not paste them. Verify by key set and count, never by value.

```bash
# key sets only — safe to print
raptor get variables -p <SRC_PROJECT> -o json | jq -r '.[].name' | sort > /tmp/src.keys
raptor get variables -p <DST_PROJECT> -o json | jq -r '.[].name' | sort > /tmp/dst.keys
diff /tmp/src.keys /tmp/dst.keys && echo "KEY PARITY OK"
```

Use `raptor create variable -f <file>` for bulk, `--secret` for secrets, `--global` for
the auto-inject ones, `--env-values <ENV>=<VALUE>` for per-environment values.

**c. Emit resource docs.** One per legacy resource, values driven from **live state**, not
from the source blueprint (a blueprint can carry a value the cloud never had).

```bash
raptor apply resource <KIND>/<FLAVOR>_legacy/<VERSION> -n <NAME> -p <DST_PROJECT> \
  --spec-file <spec.yaml> --input <INPUT>=<TYPE>/<RESOURCE> --dry-run
```

Env-specific values (region, zones, names, allowlists, webhook URLs) belong in the
**environment override**, not the blueprint. The blueprint stays portable.

```bash
raptor apply override -p <DST_PROJECT> -e <ENV> ...
```

**d. Deploy `cloud_account` alone.** A no-op deploy — data sources and outputs only, zero
cloud infrastructure — so downstream modules can read its outputs.

```bash
raptor create release -p <DST_PROJECT> -e <ENV> --target cloud_account/<NAME> --plan -w
raptor create release -p <DST_PROJECT> -e <ENV> --target cloud_account/<NAME> -w
```

**e. Emit `imports.tf`.** New address ← provider-native ID, read from the *source*
environment's terraform state.

```hcl
import {
  to = module.level2.module.redis_cache.google_redis_instance.this
  id = "projects/<p>/locations/<l>/instances/cache"
}
```

For `is_old` modules the `to` address uses the **intent**, not the legacy directory name:
`module.level2.module.helm_simple_tekton` → `module.level2.module.helm_tekton`.

Inject it base64-encoded — raptor's `-c` CSV parser chokes on bare quotes. Keep each `-c`
body under ~25KB / ~100 imports; raptor silently truncates larger ones.

**f. GATE — plan only. Mutates nothing.**

```bash
raptor create custom-release -p <DST_PROJECT> -e <ENV> --no-refresh \
  -c "echo '<b64-imports.tf>' | base64 -d > imports.tf" \
  -c "terraform init -input=false" \
  -c "terraform plan -input=false"
```

Poll status, then fetch logs once and grep the verdict. **Never `sleep`/`tail` to wait.**

```bash
raptor logs release -p <DST_PROJECT> -e <ENV> <release-id> --stream \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | grep -E 'Plan:|must be replaced|will be destroyed|Error:'
```

Capture the release id from `-o json`, never from table output.

**g. IMPORT.** Only after a clean gate. Writes to terraform state; touches no cloud
infrastructure.

**h. RE-GATE.** Plan again. Confirm still clean.

---

## 6. Guardrails — the checks a script would have made for you

There are no scripts. These three failures are **silent**. Run every check.

**G1 — terraform is byte-identical.** Any edit to `main.tf` voids the 0-diff-by-
construction property.

```bash
diff <legacy-dir>/main.tf <module>/main.tf && echo "G1 OK: byte-identical"
```

**G2 — `advanced` key renamed in lockstep with `flavor`.** `main.tf.mustache` reads the
block *by flavor key*:

```hcl
advanced = lookup(lookup(local.input_{{key}}, "advanced", {}), "{{flavor}}", {})
```

Rename the flavor without renaming `advanced.<flavor>` and the block resolves to `{}`.
**No error. Possibly no plan diff. Just missing config.**

```bash
# must return NOTHING — no advanced key may match a pre-rename flavor
grep -rE 'advanced:' -A2 <doc.yaml> | grep -E '<OLD_FLAVOR>:' && echo "G2 FAIL" || echo "G2 OK"
```

**G3 — vendoring closure is complete.** No `source` may escape the module directory.

```bash
grep -rE 'source\s*=\s*"\.\.' <module>/ && echo "G3 FAIL: unvendored ../ source" || echo "G3 OK"
```

`raptor create iac-module --dry-run --block-remote-modules` is the machine version.

**G4 — address translation recorded.** For every `is_old` resource, the `imports.tf` `to`
address uses the **intent**, not the directory name. Cross-check against §1.

**G5 — the gate is never loosened.** No `--allow-destroy`. No `--skip-validation`. If the
plan is not clean, the module is wrong.

---

## 7. Safety

- Plan-gate before every apply. `0 to change, 0 to destroy`, nothing `must be replaced`.
- One resource type proven end-to-end before bulk. Then batch (~100/release).
- Custom releases **serialize per environment** — "deployment already in progress" means
  a concurrent one is running.
- Model values from **live**, not from the source blueprint. Blueprints drift.
- The cloud `list`/`describe` API lies by omission. The terraform plan/refresh is the
  authoritative read of live. When they disagree, **the plan is right.**
- Never pull secret values into context. Facets injects provider config server-side.
- Re-plan a FAILED-but-created resource. Never destroy/recreate.
- Scope ("is this ours to manage?") is the owner's call, not a technical one. Ask.

---

## 8. Worked examples (fill as types complete)

```
  <intent>/<flavor>:  source_dir <...>  is_old <y/n>  vendored <n modules>
                      address <old> -> <new>
                      plan <N to import / 0 to change / 0 to destroy>   G1..G5 <all OK>
```

---

## 9. Nuances log (new gotchas → PR back into this SOP)

```
  - actions.tf fakes an address-set match → exclude it before comparing modules
  - legacy modules reference OTHER legacy modules by relative path → vendoring is a graph walk
  - <symptom> → <cause> → <fix>
```
