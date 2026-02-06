# Facets Module Repository

## MANDATORY: Read Before Any Task

**Always read `.claude/skills/module_writing.md` first.** This is the complete guide to how Facets modules work — facets.yaml structure, Terraform file conventions, output types, provider configuration, and the full development workflow. Without reading it, you will not understand this codebase.

## Repository Structure

```
modules/{intent}/{flavor}/{version}/   - Core infrastructure modules
datastore/{tech}/{flavor}/{version}/   - Database modules
outputs/{type-name}/                   - Output type schemas (@facets/*)
```

## Module Files

| File | Purpose |
|------|---------|
| `facets.yaml` | Module definition (spec schema, inputs, outputs, sample) |
| `variables.tf` | `var.instance` (spec) and `var.inputs` (dependencies) |
| `main.tf` | Terraform resources |
| `outputs.tf` | `output_attributes` and `output_interfaces` locals (NO `output` blocks) |

## Raptor Commands

```bash
# Validate module (always start with this)
raptor create iac-module -f <module-path> --dry-run

# If security scan fails, retry with skip (but report findings to user)
raptor create iac-module -f <module-path> --dry-run --skip-security-scan

# Upload after validation passes
raptor create iac-module -f <module-path>
```

## Finding Module Standards

Look for `*_module_standard*.md` in the relevant directory:
- `modules/service/` → `service_module_standard.md`
- `modules/network/` → `network_module_standard.md`
- `modules/cloud_account/` → `cloud_account_module_standard.md`
- `modules/kubernetes_node_pool/` → `kubernetes_node_pool_module_standard.md`
- `modules/workload_identity/` → `workload_identity_module_standard.md`
- `datastore/` → `datastore_module_standards.md`

## Validation Rules

See **rules.md** for complete validation ruleset with good/bad examples.

## Behavior Guidelines

- **NEVER** auto-skip validation - always report issues to user
- Report security scan results in **table format**
- Branch naming: `fix/<issue-number>-<short-description>`
- If provider issues (aws3tooling, facets provider), **report to user**
- **NEVER** use `--skip-validation` flag
