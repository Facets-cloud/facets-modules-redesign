# Network — Anycloud (AWS VPC or GCP VPC)

A multi-cloud reference network that is optimized for Kubernetes. The module
branches on `inputs.cloud_account.attributes.cloud_provider`. See
[`modules/ANYCLOUD_PATTERN.md`](../../../ANYCLOUD_PATTERN.md).

- **Clouds:** aws, gcp
- **Input:** `cloud_account` → `@facets/any_cloud_account` (aws, google providers)
- **Output type:** `@facets/any_cloud_network`

| Cloud | File | Resources |
|-------|------|-----------|
| AWS | `aws.tf` | VPC across N AZs, public/private/database subnets, single or per-AZ NAT, gateway + interface VPC endpoints |
| GCP | `gcp.tf` | VPC network, private/public/database/internal-LB subnets, GKE secondary ranges, Google-services peering, Cloud NAT, firewall rules, optional Serverless VPC connector |

## Usage

```yaml
kind: network
flavor: anycloud
version: "1.0"
spec:
  cidr: 10.0.0.0/16    # /16; subnets are derived from it on both clouds
  aws:
    nat_gateway:
      strategy: single  # or per_az
  gcp:
    enable_flow_logs: false
```

Both `spec.aws` and `spec.gcp` can be set. Only the block of the active cloud
is applied.

## Outputs — `@facets/any_cloud_network`

- **attributes** (both clouds): `cloud_provider`, `network_id`, `vpc_id`,
  `cidr`, `region`, `project_id`, `private_subnet_ids`, `public_subnet_ids`,
  `database_subnet_ids`
- **interfaces.aws**: AZs, IGW/NAT IDs, DB subnet group, VPC endpoint IDs
- **interfaces.gcp**: zones, VPC self link/name, GKE pod/service range names
  and CIDRs, router/NAT, VPC connector, private services range

The inactive cloud's interface keeps the same keys with `null` or empty values.
