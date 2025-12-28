# Karpenter Autoscaler Module

Deploys Karpenter autoscaler for Amazon EKS clusters with automatic node provisioning and cost optimization.

## Overview

Karpenter is a Kubernetes node autoscaler that directly provisions EC2 instances based on pod requirements, providing:

- **Faster Scaling**: 3-5x faster than Cluster Autoscaler (30-60 seconds vs 3-5 minutes)
- **Cost Optimization**: 20-50% cost savings through intelligent instance selection
- **Flexibility**: Automatically selects from 600+ instance types
- **Spot Instance Support**: Advanced Spot/On-Demand mixing with automatic fallback
- **Consolidation**: Automatic bin-packing and node replacement

## Prerequisites

Before deploying this module, ensure:

1. **EKS Cluster**: You have an existing EKS cluster deployed
2. **OIDC Provider**: The cluster has an OIDC provider configured
3. **Subnet Tags**: Private subnets must be tagged with:
   ```
   karpenter.sh/discovery = <cluster-name>
   ```
4. **Security Group Tags**: Node security groups must be tagged with:
   ```
   karpenter.sh/discovery = <cluster-name>
   ```

## Quick Start

### Basic Configuration

```yaml
kind: autoscaler
flavor: karpenter
version: "1.0"
spec:
  karpenter_version: "1.0.1"
  enable_spot_instances: true
  enable_consolidation: true
  node_pools:
    default:
      instance_families: [t3, t3a]
      instance_sizes: [medium, large, xlarge]
      capacity_types: [on-demand, spot]
```

### Advanced Configuration with Multiple Node Pools

```yaml
spec:
  karpenter_version: "1.0.1"
  enable_spot_instances: true
  enable_consolidation: true
  interruption_handling: true

  node_pools:
    # General purpose workloads
    general:
      cpu_limits: "500"
      memory_limits: "500Gi"
      instance_families: [t3, t3a, t2]
      instance_sizes: [medium, large, xlarge]
      capacity_types: [spot, on-demand]
      architecture: [amd64]
      labels:
        workload-type: general

    # Compute-intensive workloads
    compute:
      cpu_limits: "200"
      memory_limits: "400Gi"
      instance_families: [c5, c5a, c6i]
      instance_sizes: [xlarge, 2xlarge, 4xlarge]
      capacity_types: [spot, on-demand]
      architecture: [amd64]
      labels:
        workload-type: compute
      taints:
        dedicated: compute

    # Memory-intensive workloads
    memory:
      cpu_limits: "100"
      memory_limits: "800Gi"
      instance_families: [r5, r5a, r6i]
      instance_sizes: [large, xlarge, 2xlarge]
      capacity_types: [on-demand]
      architecture: [amd64]
      labels:
        workload-type: memory
      taints:
        dedicated: memory

    # ARM-based workloads (cost-optimized)
    arm:
      cpu_limits: "200"
      memory_limits: "400Gi"
      instance_families: [t4g, c6g, m6g]
      instance_sizes: [medium, large, xlarge]
      capacity_types: [spot, on-demand]
      architecture: [arm64]
      labels:
        workload-type: arm
        arch: arm64

  tags:
    Team: platform
    CostCenter: engineering
```

## Configuration Reference

### Core Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `karpenter_version` | string | - | Karpenter version to deploy (required) |
| `enable_spot_instances` | bool | `true` | Allow Spot instance provisioning |
| `enable_consolidation` | bool | `true` | Enable automatic node consolidation |
| `interruption_handling` | bool | `true` | Enable Spot interruption handling |

### Node Pool Configuration

Each node pool supports:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `cpu_limits` | string | `"1000"` | Max CPU cores for this pool |
| `memory_limits` | string | `"1000Gi"` | Max memory for this pool |
| `instance_families` | list(string) | `["t3", "t3a"]` | EC2 instance families |
| `instance_sizes` | list(string) | `["medium", "large", "xlarge"]` | Instance sizes |
| `capacity_types` | list(string) | `["on-demand", "spot"]` | Capacity types |
| `architecture` | list(string) | `["amd64"]` | CPU architecture |
| `labels` | map(string) | `{}` | Kubernetes node labels |
| `taints` | map(string) | `{}` | Kubernetes node taints |

## How Karpenter Works

### Provisioning Flow

1. **Pod Pending**: Kubernetes scheduler cannot place a pod
2. **Analysis**: Karpenter analyzes pod requirements (CPU, memory, labels, taints)
3. **Instance Selection**: Karpenter selects optimal instance type from configured pools
4. **Provisioning**: Directly launches EC2 instance via AWS API (30-45 seconds)
5. **Scheduling**: Pod is scheduled on the new node

### Consolidation

When enabled, Karpenter continuously:
- Monitors node utilization
- Identifies under-utilized nodes
- Replaces multiple small nodes with fewer large nodes
- Deletes empty nodes after 30 seconds

### Interruption Handling

For Spot instances, Karpenter:
- Monitors AWS interruption events via SQS/EventBridge
- Gracefully drains nodes before termination
- Automatically provisions replacement capacity

## Instance Selection Example

For a pod requesting:
```yaml
resources:
  requests:
    cpu: "2"
    memory: "4Gi"
nodeSelector:
  workload-type: compute
```

Karpenter will:
1. Look at the `compute` node pool
2. Filter instance families: `[c5, c5a, c6i]`
3. Filter sizes: `[xlarge, 2xlarge, 4xlarge]`
4. Check Spot vs On-Demand pricing
5. Select cheapest option (likely `c5a.xlarge` on Spot)

## Cost Optimization Tips

1. **Enable Spot**: Save 70-90% vs On-Demand
   ```yaml
   capacity_types: [spot, on-demand]
   ```

2. **Use Instance Families**: Allow multiple families for better Spot availability
   ```yaml
   instance_families: [c5, c5a, c6i, c5n]
   ```

3. **Enable Consolidation**: Automatically optimize node usage
   ```yaml
   enable_consolidation: true
   ```

4. **Consider ARM**: 20% cheaper than x86
   ```yaml
   architecture: [arm64, amd64]
   ```

## Monitoring

### Key Metrics

Karpenter exposes Prometheus metrics:

```
karpenter_nodes_created
karpenter_nodes_terminated
karpenter_pods_startup_duration_seconds
karpenter_consolidation_actions_performed
```

### Logs

View Karpenter controller logs:
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f
```

## Troubleshooting

### Pods not being scheduled

Check:
1. Node pool limits not exceeded
2. Instance requirements can be satisfied
3. Subnet/Security group tags are correct

### Nodes not terminating

Check:
1. Consolidation is enabled
2. Pods have appropriate PodDisruptionBudgets
3. No local storage preventing eviction

### Spot interruptions causing issues

Enable interruption handling:
```yaml
interruption_handling: true
```

## Migration from Cluster Autoscaler

1. Deploy Karpenter alongside Cluster Autoscaler
2. Create NodePools with similar capacity
3. Cordon existing ASG nodes
4. Scale down ASG minimums to 0
5. Let Karpenter provision new nodes
6. Remove Cluster Autoscaler when ready

## Outputs

The module provides:

- `karpenter_namespace`: Namespace where Karpenter is deployed
- `karpenter_service_account`: ServiceAccount name
- `karpenter_version`: Deployed version
- `controller_role_arn`: IAM role ARN for controller
- `node_role_arn`: IAM role ARN for nodes
- `node_instance_profile_name`: Instance profile name
- `interruption_queue_name`: SQS queue for interruptions

## Resources Created

- IAM Role: Karpenter Controller (with OIDC)
- IAM Role: Karpenter Nodes
- IAM Instance Profile: For EC2 nodes
- Helm Release: Karpenter controller
- SQS Queue: Interruption handling (if enabled)
- EventBridge Rules: Spot interruptions (if enabled)
- NodePools: Per configuration
- EC2NodeClasses: Per configuration

## References

- [Karpenter Documentation](https://karpenter.sh/)
- [AWS Workshop](https://www.eksworkshop.com/docs/autoscaling/compute/karpenter/)
- [Best Practices](https://aws.github.io/aws-eks-best-practices/karpenter/)
