---
title: "Facets Modules Validate"
description: "Validate changed Facets modules: lint against rules.md (RULE-001 through RULE-024) AND run raptor dry-run. Auto-detects changed modules from git diff."
triggers: ["facets-modules-validate", "validate against rules", "check rules", "rules validation", "lint modules", "module lint"]
version: "1.0"
category: "validation"
tags: ["validation", "rules", "module", "quality"]
icon: "shield"
---

# Facets Modules Validation

**IMPORTANT:** This skill does TWO things: (1) validates modules against `rules.md` rules (RULE-001 through RULE-024) by reading and analyzing the module files directly, and (2) runs `raptor create iac-module --dry-run` for each module. Both checks must pass.

Validate changed Facets modules against the project's `rules.md` validation ruleset.

---

## Step 1: Determine which modules to validate

Identify the set of modules to validate, in priority order:

1. **If the user passed a module path as argument** → use that path directly
2. **If on a PR branch** (not `main`) → run `git diff origin/main --name-only` to get all changed files vs main, then extract unique module directories
3. **Otherwise** → run `git diff --name-only` (unstaged) and `git diff --cached --name-only` (staged) to get locally changed files, then extract unique module directories

**Extracting module paths:** A module directory is any directory that contains a `facets.yaml` file. For each changed file, walk up its path to find the nearest `facets.yaml`. The module path is that directory (e.g., `modules/datastore/postgres/aws-rds/1.0/`).

Deduplicate the list. If no modules are found, inform the user and stop.

Print the list of modules that will be validated before proceeding.

---

## Step 2: Read rules.md and module files

1. **Read `rules.md`** from the repo root — this contains all validation rules (RULE-001 through RULE-024)
2. **For each module**, read:
   - `facets.yaml`
   - All `.tf` files in that module directory (`variables.tf`, `main.tf`, `outputs.tf`, `locals.tf`, `versions.tf`, etc.)
   - The relevant **output type schemas** from `outputs/` based on the output types declared in `facets.yaml` outputs section (e.g., if output type is `@facets/eks`, check `outputs/eks/outputs.yaml`; if `@outputs/postgres`, check `outputs/postgres/outputs.yaml`)

---

## Step 3: Validate each module against applicable rules

For each module, check every rule from rules.md. Skip rules that don't apply to the module.

### Rule applicability guide

| Rule | Category | Check if... |
|------|----------|-------------|
| RULE-001 | sample.spec | Module has a `sample` section with `spec` |
| RULE-002 | sample.spec | Module has enum fields in spec and a sample |
| RULE-003 | sample.spec | Module has a sample with spec values |
| RULE-004 | var.inputs | Module has `variables.tf` with a `var.inputs` declaration |
| RULE-005 | var.inputs | Module has both `facets.yaml` inputs and `variables.tf` |
| RULE-006 | var.inputs | Module has inputs in `var.inputs` |
| RULE-007 | spec schema | Module spec has `pattern:` fields |
| RULE-008 | spec schema | Module spec has `enum:` fields |
| RULE-009 | spec schema | Module spec uses `patternProperties` |
| RULE-010 | output schema | Module has output type schemas in `outputs/` dir |
| RULE-011 | output schema | Module has output type schemas in `outputs/` dir |
| RULE-012 | output schema | Module has both output schema and `locals.tf`/`outputs.tf` with output_attributes/output_interfaces |
| RULE-013 | terraform | Module has `.tf` files |
| RULE-014 | terraform | Module has `.tf` files referencing variables |
| RULE-015 | terraform | Module has `.tf` files accessing `var.instance.spec` or `var.instance.metadata` |
| RULE-016 | var.inputs | Module has `.tf` files accessing `var.inputs` |
| RULE-017 | terraform | Module has resources with `depends_on` |
| RULE-018 | terraform | Module has Docker image references in `.tf` files |
| RULE-019 | terraform | Module manages tags on shared resources |
| RULE-020 | facets.yaml | Always check — verify no `metadata:` top-level key |
| RULE-021 | facets.yaml | Always check — verify `intentDetails` block exists |
| RULE-022 | module design | Module has `lookup()` calls with security-related defaults |
| RULE-023 | module lifecycle | Module version changed or breaking changes detected |
| RULE-024 | terraform | Module creates cloud resources with names |

### How to check each rule

- **RULE-001**: Verify every `required` field from spec schema exists in `sample.spec` (even with empty values)
- **RULE-002**: Verify sample values match defined enum options
- **RULE-003**: Verify objects use `{}`, arrays use `[]`, no `null` values in sample
- **RULE-004**: Verify `var.inputs` uses explicit `object({...})`, not `type = any` or `map(any)`
- **RULE-005**: Cross-reference `facets.yaml` `inputs:` keys with `var.inputs` object keys — every input must be present
- **RULE-006**: Verify all input entries in `var.inputs` use `attributes`/`interfaces` nesting, not flat structure
- **RULE-007**: Scan all `pattern:` values in spec for `(?=)`, `(?!)`, `(?<=)`, `(?<!)` lookahead/lookbehind
- **RULE-008**: Check all `enum:` arrays for duplicate entries
- **RULE-009**: When `patternProperties` is used, verify `required` is inside the pattern object definition, not a sibling of `patternProperties`
- **RULE-010**: In output type schemas (`outputs/*/outputs.yaml`), verify every nested object has explicit `type: object`
- **RULE-011**: In output type schemas, verify no field uses array syntax for types (e.g., `type: [string, "null"]`)
- **RULE-012**: Cross-reference output schema field names with actual keys in `output_attributes`/`output_interfaces` in locals
- **RULE-013**: Scan `.tf` files for `required_providers` blocks — should not exist
- **RULE-014**: Scan `.tf` files for references to `var.cc_metadata`, `var.cluster`, `var.baseinfra` — these platform-injected vars are not available in modules
- **RULE-015**: Check `.tf` files for direct access of optional spec fields without `lookup()` (e.g., `var.instance.spec.optional_field` or `var.instance.metadata.x` without lookup)
- **RULE-016**: Verify `var.inputs.<name>` access patterns match the output type schema structure (e.g., using `.attributes.` when the schema has attributes)
- **RULE-017**: Check `depends_on` usage — flag if a resource has both an attribute reference AND `depends_on` to the same resource (redundant). Do NOT flag `depends_on` for CRD/CustomResource resources that lack attribute references
- **RULE-018**: Find Docker image references in `.tf` files — flag `:latest` tags or unverified registries
- **RULE-019**: Check for `aws_ec2_tag` or similar tag-management resources that may conflict with the resource owner's tags
- **RULE-020**: Verify `facets.yaml` has no top-level `metadata:` key and no `metadata` in `sample:`
- **RULE-021**: Verify `facets.yaml` has an `intentDetails` block with required fields (`type`, `description`, `displayName`, `iconUrl`)
- **RULE-022**: Find `lookup()` calls for security-related fields (`enable_encryption`, `enable_logging`, etc.) and verify defaults are secure (e.g., `true` not `false`)
- **RULE-023**: This is advisory — flag if output types or input types changed but version stayed the same (compare with git diff if possible)
- **RULE-024**: Check if module creates cloud resources with hardcoded name concatenation instead of using the `//name` utility module

---

## Step 4: Run raptor dry-run validation

For each detected module, run:

```bash
export FACETS_PROFILE=1155708878 && raptor create iac-module -f <module-path> --dry-run
```

- If the raptor dry-run **fails due to security scan**, retry with `--skip-security-scan` but report the security findings to the user in a table
- If the raptor dry-run fails for other reasons (provider issues, schema errors, etc.), report the error
- Record each module's raptor result (PASS / FAIL + error details) for the final report

---

## Step 5: Report results

### Per-module report

For each validated module, output a report in this format:

```
## modules/datastore/postgres/aws-rds/1.0

| Rule | Status | Finding |
|------|--------|---------|
| RULE-001 | PASS | — |
| RULE-002 | PASS | — |
| RULE-003 | SKIP | No sample values to check |
| RULE-004 | FAIL | var.inputs uses `type = any` instead of explicit object type |
| RULE-005 | PASS | — |
| ... | ... | ... |
| RULE-024 | SKIP | No cloud resources with names |
| Raptor dry-run | PASS/FAIL | Result or error details |

X passed, Y failed, Z skipped.
```

**Status values:**
- **PASS** — Rule checked and satisfied
- **FAIL** — Rule checked and violation found (include specific finding)
- **SKIP** — Rule not applicable to this module (include brief reason)

### Summary (if multiple modules)

After all per-module reports, output a summary:

```
## Summary

| Module | Passed | Failed | Skipped |
|--------|--------|--------|---------|
| modules/datastore/postgres/aws-rds/1.0 | 18 | 2 | 4 |
| modules/service/aws/1.0 | 20 | 0 | 4 |
| **Total** | **38** | **2** | **8** |
```

If all modules pass, add a confirmation message. If any fail, list the critical failures that should be fixed before commit.
