# Service — Anycloud (consumer example)

A multi-cloud reference workload (deployment, statefulset, cronjob or job). It
runs on an EKS or GKE cluster from `kubernetes_cluster/anycloud`. It shows how
a consumer module branches on the cloud for cloud-specific extras (here, pod
IAM) and stays cloud-neutral for everything else. See
[`modules/ANYCLOUD_PATTERN.md`](../../../ANYCLOUD_PATTERN.md).

- **Clouds:** aws, gcp
- **Output type:** `@facets/service`

## Inputs

| Input | Type | Why |
|-------|------|-----|
| `kubernetes_details` | `@facets/kubernetes-details` | kubernetes, kubernetes-alpha, helm providers (the cluster's `attributes` output) |
| `kubernetes_cluster` | `@facets/any_cloud_kubernetes_cluster` | EKS OIDC provider for IRSA (the same cluster's `default` output) |
| `cloud_account` | `@facets/any_cloud_account` | aws/google providers and `cloud_provider` |
| `kubernetes_node_pool_details` | `@facets/kubernetes_nodepool` | Optional: nodeSelector + tolerations |
| `artifactories` | `@facets/artifactories` | Optional: image pull secrets |

## Cloud permissions

| Cloud | File | What happens |
|-------|------|--------------|
| AWS | `aws.tf` | `cloud_permissions.aws.enable_irsa`: IAM role trusted by the cluster's OIDC provider for `<name>-sa`, managed policy ARNs + optional inline JSON, SA annotated with the role ARN |
| GCP | `gcp.tf` | `cloud_permissions.gcp.enable_wi`: roles granted straight to the KSA's Workload Identity principal (no GSA, no keys) |

Only the active cloud's block applies. The other is count-gated to zero.

## Usage

```yaml
kind: service
flavor: anycloud
version: "1.0"
spec:
  type: application
  runtime:
    size: { cpu: 300m, memory: 1Gi }
    ports: {}
  cloud_permissions:
    aws:
      enable_irsa: true
      iam_policies:
        s3-read: { arn: arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess }
    gcp:
      enable_wi: true
      roles:
        gcs-read: { role: roles/storage.objectViewer }
```
