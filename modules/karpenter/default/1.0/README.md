# Karpenter Controller (EKS)

Installs the Karpenter controller on an EKS cluster, with the IAM roles and
the discovery tags that it needs. Deploy this module once for each cluster.
Then add one `kubernetes_node_pool/karpenter` resource for each NodePool.

- **Cloud:** aws
- **Output type:** `@facets/karpenter-details`
- **Next module:** `kubernetes_node_pool/karpenter` reads this output to create NodePools

---

## Usage

```yaml
kind: karpenter
flavor: default
version: "1.0"
disabled: false
spec:
  karpenter_version: 1.5.0
  karpenter_replicas: 1
```

Use a Karpenter version that supports the Kubernetes version of your cluster.

---

## Inputs

| Input | Type | Required | Use |
|-------|------|----------|-----|
| `cloud_account` | `@facets/aws_cloud_account` | Yes | Gives the `aws` provider and the region |
| `eks_details` | `@facets/eks` | Yes | Gives the `helm`, `kubernetes` and `kubernetes-alpha` providers, the cluster name, the endpoint, the OIDC provider and the node security group |
| `network_details` | `@facets/aws-vpc-details` | No (default `network/default`) | Gives the private subnets that Karpenter can launch nodes in |

## Spec

| Field | Required | Default | Notes |
|-------|----------|---------|-------|
| `karpenter_version` | Yes | `1.5.0` | The Helm chart version. It must have the format `X.Y.Z` |
| `karpenter_replicas` | No | `1` | The number of controller replicas, from 1 to 5 |
| `additional_node_policies` | No | `{}` | Extra IAM policy ARNs to attach to the node role, for example for X-Ray or CloudWatch |
| `tags` | No | `{}` | Extra AWS tags for the resources of this module |

---

## What the module creates

- **The controller IAM role and policy.** The role trusts the cluster OIDC
  provider for the `kube-system/karpenter` service account. The policy lets
  Karpenter launch EC2 instances and terminate only the instances that have a
  `karpenter.sh/nodepool` tag.
- **The node IAM role and instance profile.** The role has
  `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`,
  `AmazonEC2ContainerRegistryReadOnly`, `AmazonSSMManagedInstanceCore` and the
  policies in `additional_node_policies`.
- **An EKS access entry** of type `EC2_LINUX` for the node role, so that new
  nodes can join the cluster.
- **The Karpenter Helm release** from `oci://public.ecr.aws/karpenter` in the
  `kube-system` namespace.
- **Discovery tags.** The module adds `karpenter.sh/discovery = <cluster name>`
  to each private subnet and to the node security group.

---

## Outputs — `@facets/karpenter-details`

| Attribute | Description |
|-----------|-------------|
| `karpenter_namespace` | Always `kube-system` |
| `karpenter_service_account` | Always `karpenter` |
| `karpenter_version` | The `spec.karpenter_version` value |
| `controller_role_arn` | The ARN of the controller IAM role |
| `node_role_arn` | The ARN of the node IAM role |
| `node_instance_profile_name` | The name of the node instance profile |
| `interruption_queue_name` | The SQS queue for interruption events, or an empty string |
| `helm_release_id` | The ID of the Karpenter Helm release |

---

## Notes

- **Use one instance for each cluster.** The IAM role, policy and instance
  profile names include the cluster name, so a second instance on the same
  cluster fails.
- **Interruption handling is off.** The Terraform can create an SQS queue and
  EventBridge rules for Spot interruption events, through
  `interruption_handling`. The `facets.yaml` spec does not show this field yet,
  so the default value `false` applies.
- **The module writes tags on network resources.** The discovery tags go on
  subnets and on a security group that other modules own. When you destroy this
  module, Terraform removes the tags.
