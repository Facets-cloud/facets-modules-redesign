# Kubernetes Cluster — Anycloud (EKS or GKE)

A multi-cloud reference cluster. It creates EKS on an AWS cloud account and
GKE on a GCP cloud account. See
[`modules/ANYCLOUD_PATTERN.md`](../../../ANYCLOUD_PATTERN.md).

- **Clouds:** aws, gcp
- **Inputs:** `cloud_account` → `@facets/any_cloud_account`, `network` → `@facets/any_cloud_network`

## Outputs

This module follows the repo's Provider-Exposing Module Output Convention:

| Key | Type | Providers | Contents |
|-----|------|-----------|----------|
| `default` | `@facets/any_cloud_kubernetes_cluster` | none | Common attributes plus `interfaces.aws` (cluster ARN, OIDC issuer/provider ARN, node and cluster SGs) and `interfaces.gcp` (project, pod/service ranges, network, subnetwork, OIDC issuer) |
| `attributes` | `@facets/kubernetes-details` | `kubernetes`, `helm`, `kubernetes-alpha` | `cloud_provider`, `cluster_id`, `cluster_name`, `cluster_location`, `cluster_endpoint`, CA and exec auth |

Modules that need only the providers wire to `@facets/kubernetes-details`.
Existing consumers of that type work unchanged. Modules that need EKS or GKE
details (for example IRSA) also wire the `default` output.

## Usage

```yaml
kind: kubernetes_cluster
flavor: anycloud
version: "1.0"
spec:
  cluster_version: "1.30"
  aws:
    endpoint_private_access: true
    endpoint_public_access: false
    public_access_cidrs: [10.0.0.0/8]
  gcp:
    release_channel: STABLE
    enable_private_nodes: true
  default_node_pool:
    enabled: false   # true = small system pool (EKS node group or GKE node pool)
```

## Notes

- **Exec auth on both clouds.** The kubernetes and helm providers authenticate
  with `aws-iam-authenticator` (assuming the account role) on EKS. On GKE they
  use `gke-auth-plugin`, with the service-account key passed through env and
  written to a `0600` temp file.
- **Private API endpoint by default on EKS.** Public access is opt-in and
  limited by CIDR.
- **The default node pool follows the account.** No second cloud selector is
  needed. `spec.default_node_pool.aws` is applied on AWS, `.gcp` on GCP.
