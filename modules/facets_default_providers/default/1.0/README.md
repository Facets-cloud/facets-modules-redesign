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

The new `iac-generator-releases` image does not ship that spoofed cache out of the box — a small addition to its Dockerfile is required (see below). This module tells the iac-generator to emit a `required_providers { aws3tooling = { source = "hashicorp/aws3tooling" ... } }` entry that matches the existing state binding exactly.

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
  region                 = "<aws_region>"
  skip_region_validation = true
}
provider "aws3tooling" {
  alias                  = "provider_facets_default_providers_default"
  region                 = "<aws_region>"
  skip_region_validation = true
}
```

The un-aliased block matches the state shape (`registry.terraform.io/hashicorp/aws3tooling` with no alias), which is exactly what resources in state are bound to today. The aliased copy is harmless — it's emitted automatically for `IsDefaultResource=true` resources.

## Required: name the blueprint resource `default`

The un-aliased `provider "aws3tooling" {}` block above is only emitted when the blueprint's resource is named `default` (sets `IsDefaultResource=true` in iac-generator, see `v2/internal/providers/extractor.go:47`). Any other name emits an aliased-only block, which wouldn't match state.

## Consumer module wiring

Consumer modules that reference `aws3tooling` in their terraform (e.g., for tooling-VPC data lookups) declare in their `facets.yaml`:

```yaml
inputs:
  default_providers:
    type: "@facets/aws_cloud_account"
    providers:
      - aws3tooling    # plain local name — NO dot convention
```

Per `v2/internal/modules/processor.go:175-177`, when the input is wired to a resource named `default` and the provider entry has no dot, the iac-generator **skips** adding an explicit `providers = {}` map entry. Terraform then inherits the un-aliased `aws3tooling` provider from level2 implicitly, and `provider = aws3tooling` inside the consumer module resolves to the un-aliased block — matching state.

## Required: Dockerfile change in `iac-generator-releases`

Add the spoofing layer to `iac-generator-releases/Dockerfile`. Only this one provider is covered; everything else resolves from the public registry normally:

```dockerfile
ARG TOOLING_AWS_VERSION=3.74.0
ENV TF_PLUGIN_MIRROR=/opt/tf-plugins

RUN set -eux; \
    DIR="${TF_PLUGIN_MIRROR}/registry.terraform.io/hashicorp/aws3tooling/${TOOLING_AWS_VERSION}/linux_amd64"; \
    mkdir -p "$DIR"; \
    curl -fsSL "https://releases.hashicorp.com/terraform-provider-aws/${TOOLING_AWS_VERSION}/terraform-provider-aws_${TOOLING_AWS_VERSION}_linux_amd64.zip" -o /tmp/aws.zip; \
    unzip -p /tmp/aws.zip "terraform-provider-aws*" > "${DIR}/terraform-provider-aws3tooling_v${TOOLING_AWS_VERSION}"; \
    chmod 0755 "${DIR}/terraform-provider-aws3tooling_v${TOOLING_AWS_VERSION}"; \
    rm /tmp/aws.zip; \
    printf 'provider_installation {\n  filesystem_mirror {\n    path    = "%s"\n    include = ["registry.terraform.io/hashicorp/aws3tooling"]\n  }\n  direct {\n    exclude = ["registry.terraform.io/hashicorp/aws3tooling"]\n  }\n}\n' "${TF_PLUGIN_MIRROR}" > /etc/terraformrc

ENV TF_CLI_CONFIG_FILE=/etc/terraformrc
```

Image-size impact: ~150 MB (one unzipped aws 3.74 binary).

## Spec

| Field | Type | Default | Description |
|---|---|---|---|
| `aws_region` | string | `""` | Region for the aws3tooling provider. Blank inherits `AWS_REGION` from the pod env. |

## Output

- Type: `@facets/aws_cloud_account`
- Providers exposed: `aws3tooling` → `hashicorp/aws3tooling` (spoofed source, version `= 3.74.0`)

## Migration steps for capillary-cloud-tf envs

1. Run `scratch-cleanup-oneliner.sh` in the release pod (removes 11 scratch resources).
2. Ship the Dockerfile change in `iac-generator-releases` so new pods have the spoofed aws3tooling binary.
3. Add this module to the blueprint with resource name `default`.
4. For each consumer module in `facets-modules-redesign` that uses the `aws3tooling` local name, declare the `providers: [aws3tooling]` input wiring in its facets.yaml.
5. Retire `capillary-cloud-tf/tfmain/scripts/cleanup_aws_tooling_v2.sh` — the iac-generator now emits the right shape natively.

**No `terraform state replace-provider` needed.** The state binding (`registry.terraform.io/hashicorp/aws3tooling`, un-aliased) matches the iac-generator's output after these steps.

## Open items (follow-ups, not in this module)

- Icon at `icons/facets_default_providers.svg`
- `project-type/{aws,gcp,azure}/project-type.yml` entries
- `index.html` catalog entry + top-level `README.md` section
- Internal pages (`app/internal/*`)
- If/when other legacy locals need to migrate (`aws3`, `aws4`, `aws5`, `aws593`, `aws6`, `helm3`, `helm-release-pod`, `cloudflare4`, `cloudflare4a`), extend both this module's `outputs.providers` and the Dockerfile's spoofing loop similarly.
