# Multi-cloud reference modules (anycloud)

The `anycloud` flavor is a **reference pattern**. One module per intent covers
both AWS and GCP. You choose the cloud **once**, on the cloud account. Every
downstream resource then follows it.

The problem it solves is the "twin blueprint". Without it, a blueprint that
must run on AWS in one environment and on GCP in another needs two copies of
each resource (`network` + `network-gcp`, `cluster` + `cluster-gcp`, …), and
you disable one side per environment. With anycloud there is one resource per
intent and one override per environment: `cloud_account.spec.cloud_provider`.

> These modules are examples to copy and extend. They are **not** part of any
> project type in `project-type/` and are not listed in the catalog page.

## Modules

| Module | Output(s) | Notes |
|--------|-----------|-------|
| `cloud_account/anycloud/1.0` | `default` → `@facets/any_cloud_account` (aws, google, google-beta providers) | The only per-environment switch: `spec.cloud_provider: AWS \| GCP` |
| `network/anycloud/1.0` | `default` → `@facets/any_cloud_network` | AWS VPC (public/private/database subnets, NAT, endpoints) or GCP VPC (GKE secondary ranges, Cloud NAT, firewall) |
| `kubernetes_cluster/anycloud/1.0` | `default` → `@facets/any_cloud_kubernetes_cluster` (no providers)<br>`attributes` → `@facets/kubernetes-details` (kubernetes, helm, kubernetes-alpha) | EKS or GKE |
| `service/anycloud/1.0` | `default` → `@facets/service` | Consumer example: workload + same-cloud pod IAM (EKS IRSA / GKE Workload Identity) |
| `config_map/anycloud/1.0` | `default` → `@facets/any_cloud_config_map` | Consumer example: pure Kubernetes, needs only the providers |

## How it fits together

```
 per-env override: cloud_provider = AWS | GCP
            │
            ▼
 ┌──────────────────────────────────────────┐
 │ cloud_account/anycloud                   │
 │  providers: aws + google + google-beta   │
 │  inactive cloud: same keys, null values  │
 └────────────────────┬─────────────────────┘
                      │ attributes.cloud_provider (read by everything below)
                      ▼
 ┌──────────────────────────────────────────┐
 │ network/anycloud                         │
 │  aws.tf (count = AWS)  VPC, subnets, NAT │
 │  gcp.tf (count = GCP)  VPC, ranges, NAT  │
 └────────────────────┬─────────────────────┘
                      ▼
 ┌──────────────────────────────────────────┐
 │ kubernetes_cluster/anycloud              │
 │  aws.tf (count = AWS)  EKS               │
 │  gcp.tf (count = GCP)  GKE               │
 └──────────┬─────────────────────┬─────────┘
            │ default             │ attributes
            │ @facets/any_cloud_  │ @facets/kubernetes-details
            │ kubernetes_cluster  │ + kubernetes / helm providers
            │ (OIDC, SGs, ranges) │
            │          ┌──────────┴───────────┐
            │          ▼                      ▼
            │  ┌─────────────────┐  ┌─────────────────────┐
            └─►│ service/        │  │ config_map/anycloud │
               │ anycloud        │  │ (pure Kubernetes)   │
               │ aws.tf IRSA     │  └─────────────────────┘
               │ gcp.tf WI       │
               └─────────────────┘
```

## The five rules

### 1. The cloud account owns the switch and exposes every provider

`cloud_account/anycloud` has `spec.cloud_provider` (`AWS` or `GCP`). It is the
only per-environment cloud setting. The module **always** exposes `aws`,
`google` and `google-beta`, because a module's provider list cannot change
between environments. Only the selected cloud gets real credentials.

### 2. The inactive side is null-keyed with the same keys, never `{}`

A literal `{}` loses its object type across the module boundary. A provider
block that reads `attributes.aws.role_arn` then fails with "object with no
attributes" in a GCP environment. So the inactive side keeps every key with a
null value:

```hcl
aws = local.is_aws ? { role_arn = ..., external_id = ..., region = ... } : {
  role_arn = null, external_id = null, region = null  # aws provider skips assume_role
}
gcp = local.is_gcp ? { project_id = ..., credentials = ..., access_token = null, region = ... } : {
  project_id = null, credentials = null, region = null,
  access_token = "inactive-cloud-stub-token"          # google provider configures without ADC
}
```

The same rule applies to every module's `interfaces.aws` / `interfaces.gcp`.

### 3. Downstream modules branch on `cloud_provider` and count-gate per cloud

```hcl
locals {
  cloud_provider = var.inputs.cloud_account.attributes.cloud_provider
  is_aws         = local.cloud_provider == "AWS"
  is_gcp         = local.cloud_provider == "GCP"
}

# aws.tf
resource "aws_vpc" "main" {
  count = local.is_aws ? 1 : 0
  ...
}

# outputs: read the active side defensively
vpc_id = try(aws_vpc.main[0].id, null)
```

Put AWS resources in `aws.tf` and GCP resources in `gcp.tf`. Gate every
resource and data source with `count`/`for_each`. Keep each gate plan-known:
gate on spec values or `cloud_provider`, never on a computed attribute of a
resource that is created in the same release.

### 4. Common keys in `attributes`, cloud-specific keys in `interfaces.<cloud>`

`attributes` holds what every consumer needs on either cloud (`cloud_provider`,
`network_id`, `private_subnet_ids`, `cluster_endpoint`, …). `interfaces.aws`
and `interfaces.gcp` hold the rest (EKS OIDC ARN, GKE secondary range names,
…). A consumer that only reads `attributes` is cloud-neutral for free.

Modules that expose Terraform providers also follow the repo's
**Provider-Exposing Module Output Convention**. `kubernetes_cluster/anycloud`
publishes `default` (cloud-specific details, no providers) and `attributes`
(the existing `@facets/kubernetes-details` type, with providers). Any module
that consumes `@facets/kubernetes-details` works on an anycloud cluster
without changes.

### 5. Keep the standard credential fetch, gated per cloud

The cloud account reads credentials with the standard Facets platform script,
one `data "external"` per cloud, each count-gated so only the selected cloud's
secret is fetched:

```hcl
data "external" "aws_fetch_cloud_secret" {
  count   = local.is_aws ? 1 : 0
  program = ["python3", "/sources/primary/capillary-cloud-tf/tfmain/scripts/cloudaccount-fetch-secret/secret-fetcher.py",
             var.instance.spec.aws_cloud_account, "AWS"]
}
```

## Using it

Upload the output types first, then the modules:

```bash
for t in any_cloud_account any_cloud_network any_cloud_kubernetes_cluster any_cloud_config_map; do
  raptor create output-type -f outputs/$t/outputs.yaml --if-absent
done

for m in cloud_account network kubernetes_cluster service config_map; do
  raptor create iac-module -f modules/$m/anycloud/1.0
done
```

Then build one blueprint with one resource per intent. Set
`cloud_account.spec.cloud_provider` (and that cloud's account and region) as
an environment override.

**Prompt for Praxis:**

```
Using the anycloud reference modules in the facets-modules-redesign repo
(modules/ANYCLOUD_PATTERN.md), set up a blueprint that runs on AWS in staging
and on GCP in production: one cloud_account, network, kubernetes_cluster and
service, with cloud_provider set per environment as an override.
```

**Prompt for Praxis (extend the pattern):**

```
Write a new <intent>/anycloud module following modules/ANYCLOUD_PATTERN.md:
branch on inputs.cloud_account.attributes.cloud_provider, put AWS resources in
aws.tf and GCP resources in gcp.tf with count gates, null-key the inactive
cloud's interfaces, and add an @facets/any_cloud_<intent> output type.
```

## Things to know

- **The account fields are override-only.** Account and region fields are
  `x-ui-overrides-only`. Set them per environment together with
  `cloud_provider`.
- **Switching an existing environment's cloud is a replace.** Changing
  `cloud_provider` destroys the old cloud's resources and creates the new
  ones. Choose the cloud when you create the environment.
- **The service needs both cluster outputs.** `service/anycloud` takes its
  providers from `kubernetes_details` (`attributes` output). It reads the EKS
  OIDC provider for IRSA from `kubernetes_cluster` (`default` output). Wire
  both to the same cluster resource.
