# facets_default_providers / default / 1.0

Preserves the legacy `aws3tooling` local provider name that the old Python IaC generator emitted, so `capillary-cloud-tf` envs can move to the new iac-generator flow without state surgery.

## Background

The legacy Python generator emitted blueprints containing:

```hcl
provider "aws3tooling" {
  region = var.cc_region
  ...
}
```

...without a matching `required_providers` entry. Terraform implicitly synthesizes a provider source named `registry.terraform.io/hashicorp/aws3tooling` — a path that does not exist on the public registry. The legacy release-pod image works around this by **physically placing the real hashicorp/aws binary under that spoofed path** (see `facets-iac/.github/workflows/tf-caching.yml:43`), so `terraform init` resolves it from the local plugin cache.

The companion Dockerfile change in `iac-generator-releases` ports that spoofing to the new release-pod image (see the [open PR](https://github.com/Facets-cloud/iac-generator-releases/pull/4)). This module tells the iac-generator to emit a `required_providers { aws3tooling = { source = "hashicorp/aws3tooling" ... } }` entry that matches the existing state binding exactly.

## Configuration: intentionally empty spec — env-var driven

`spec.properties` is **intentionally empty** (`{}`). The aws provider reads all its configuration (`region`, credentials) from the pod's environment variables — `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (and the IRSA / instance-profile fallbacks) — using the standard AWS provider env-var discovery chain. This is deliberate for three reasons:

1. **Consistency with pod config**: capillary-cloud-tf release pods already set `AWS_REGION` in `legacy_setup.sh`. Re-declaring it as a spec field would let users override the env value silently.
2. **Avoids blueprint bloat**: the module exists purely to make the iac-generator emit the right provider shape. There's no user-facing knob worth exposing.
3. **Simpler migration**: no blueprint edits required to pick up the provider — add the module, match env vars, done.

`var.instance.spec` in `variables.tf` is `object({})` and `locals.output_attributes` is `{}` to reflect this. `sample.spec` is `{}`.

If a future env ever needs an explicit region (not inherited from `AWS_REGION`), that's a version bump (RULE-023) to add the field — not a silent change.

## What the iac-generator emits from this module

When the blueprint has a resource of kind `facets_default_providers`, flavor `default`, **named `default`** (important — see below), the iac-generator produces in `level2/`:

**versions.tf**
```hcl
terraform {
  required_providers {
    aws3tooling = {
      source  = "hashicorp/aws3tooling"
      version = "= 3.74.0"
    }
  }
}
```

**provider.tf**
```hcl
provider "aws3tooling" {
  skip_region_validation = true
}
provider "aws3tooling" {
  alias                  = "provider_facets_default_providers_default"
  skip_region_validation = true
}
```

The un-aliased block matches the state shape (`registry.terraform.io/hashicorp/aws3tooling` with no alias), which is exactly what resources in state are bound to today. The aliased copy is harmless — it's emitted automatically for `IsDefaultResource=true` resources.

No `region` attribute is emitted; the aws provider picks it up from `AWS_REGION` at runtime.

## Required: name the blueprint resource `default`

The un-aliased `provider "aws3tooling" {}` block above is only emitted when the blueprint's resource is named `default` (sets `IsDefaultResource=true` in iac-generator, see `v2/internal/providers/extractor.go:47`). Any other name emits an aliased-only block, which wouldn't match state.

## Consumer module wiring

Consumer modules that reference `aws3tooling` in their terraform (e.g., for tooling-VPC data lookups) declare in their `facets.yaml`:

```yaml
inputs:
  default_providers:
    type: "@facets/facets_default_providers"
    providers:
      - aws3tooling    # plain local name — NO dot convention
```

Per `v2/internal/modules/processor.go:175-177`, when the input is wired to a resource named `default` and the provider entry has no dot, the iac-generator **skips** adding an explicit `providers = {}` map entry. Terraform then inherits the un-aliased `aws3tooling` provider from level2 implicitly, and `provider = aws3tooling` inside the consumer module resolves to the un-aliased block — matching state.

## Required: Dockerfile change in `iac-generator-releases`

The companion change lives in [iac-generator-releases PR #4](https://github.com/Facets-cloud/iac-generator-releases/pull/4). Summary of what it does:

- Downloads the real `hashicorp/aws 3.74.0` Linux binary
- Renames it to `terraform-provider-aws3tooling_v3.74.0`
- Places it at `/usr/local/share/terraform/plugins/registry.terraform.io/hashicorp/aws3tooling/3.74.0/linux_amd64/`

That directory is one of terraform 1.5.7's **implicit filesystem-mirror discovery paths**, so no `.terraformrc` or `TF_CLI_CONFIG_FILE` env vars are required. Image-size impact: ~150 MB.

Both PRs must land together — the module emits a `required_providers` entry pointing at a source path that only exists because the Dockerfile created it.

## Output

- Type: `@facets/facets_default_providers` — **new, dedicated** output type for provider bundles, defined in `outputs/facets_default_providers/outputs.yaml`.
- Providers exposed: `aws3tooling` → `hashicorp/aws3tooling` (spoofed source, version `= 3.74.0`)
- Output attributes: `{}` (intentionally empty — see "Configuration" above)

## Why a dedicated output type and not `@facets/aws_cloud_account`

This module does not represent a cloud account — it exposes legacy provider aliases. Reusing `@facets/aws_cloud_account` would imply a data contract that doesn't apply here (aws_iam_role, aws_region, external_id, session_name) and would let consumers wire this to inputs that expect a cloud account, producing confusing failure modes. The `@facets/facets_default_providers` type has an intentionally empty attribute schema — consumers only wire to it to pick up the aliased providers.

## Migration steps for capillary-cloud-tf envs

1. Run `scratch-cleanup-oneliner.sh` in the release pod (removes 11 scratch resources — separate workstream).
2. Merge and roll out [iac-generator-releases PR #4](https://github.com/Facets-cloud/iac-generator-releases/pull/4) so new pods ship with the spoofed aws3tooling binary.
3. Merge this module.
4. Add this module to the blueprint with **resource name `default`**.
5. For each consumer module in `facets-modules-redesign` that uses the `aws3tooling` local name, declare the `providers: [aws3tooling]` input wiring in its facets.yaml.
6. Retire `capillary-cloud-tf/tfmain/scripts/cleanup_aws_tooling_v2.sh` — the iac-generator now emits the right shape natively.

**No `terraform state replace-provider` needed.** The state binding (`registry.terraform.io/hashicorp/aws3tooling`, un-aliased) matches the iac-generator's output after these steps.

## Open items (follow-ups, not in this module)

- Icon at `icons/facets_default_providers.svg`
- `project-type/{aws,gcp,azure}/project-type.yml` entries
- `index.html` catalog entry + top-level `README.md` section
- Internal pages (`app/internal/*`)
- If/when other legacy locals need to migrate (`aws3`, `aws4`, `aws5`, `aws593`, `aws6`, `helm3`, `helm-release-pod`, `cloudflare4`, `cloudflare4a`), extend both this module's `outputs.providers` and the Dockerfile's spoofing loop similarly.
