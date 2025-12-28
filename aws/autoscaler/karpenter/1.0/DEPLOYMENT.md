# Karpenter Deployment Guide

## Prerequisites Checklist

Before deploying Karpenter, ensure:

### 1. Tag Your Subnets
Private subnets must be tagged for Karpenter discovery:

```bash
CLUSTER_NAME="your-cluster-name"
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.resourcesVpcConfig.vpcId" --output text)

# Get private subnet IDs
SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:kubernetes.io/role/internal-elb,Values=1" \
  --query 'Subnets[*].SubnetId' --output text)

# Tag subnets
for SUBNET_ID in $SUBNET_IDS; do
  aws ec2 create-tags \
    --resources $SUBNET_ID \
    --tags Key=karpenter.sh/discovery,Value=$CLUSTER_NAME
done
```

### 2. Tag Security Groups
Node security groups must be tagged:

```bash
# Get node security group ID from EKS
SG_ID=$(aws eks describe-cluster --name $CLUSTER_NAME \
  --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)

# Tag security group
aws ec2 create-tags \
  --resources $SG_ID \
  --tags Key=karpenter.sh/discovery,Value=$CLUSTER_NAME
```

### 3. Verify OIDC Provider
Check that your cluster has OIDC provider:

```bash
aws eks describe-cluster --name $CLUSTER_NAME \
  --query "cluster.identity.oidc.issuer" --output text
```

## Deploy Karpenter Module

### Via Facets

```yaml
kind: autoscaler
flavor: karpenter
version: "1.0"
metadata:
  name: karpenter-autoscaler
spec:
  karpenter_version: "1.0.1"
  enable_spot_instances: true
  enable_consolidation: true
  interruption_handling: true
  
  node_pools:
    default:
      cpu_limits: "1000"
      memory_limits: "1000Gi"
      instance_families: [t3, t3a, t2]
      instance_sizes: [medium, large, xlarge, 2xlarge]
      capacity_types: [spot, on-demand]
      architecture: [amd64]
```

## Verification

### 1. Check Karpenter Controller
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f
```

### 2. Check NodePools
```bash
kubectl get nodepools
kubectl get ec2nodeclasses
```

### 3. Test Autoscaling

Deploy test workload:
```bash
kubectl apply -f example-deployment.yaml
kubectl scale deployment inflate --replicas=5
```

Watch Karpenter provision nodes:
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f
kubectl get nodes -w
```

Expected log output:
```
INFO    controller.provisioner  created nodeclaim       {"commit": "abc123", "nodeclaim": "default-xyz"}
INFO    controller.nodeclaim    launched instance       {"commit": "abc123", "instance": "i-1234567890abcdef0"}
```

## Post-Deployment Tasks

### 1. Remove Cluster Autoscaler (if present)
```bash
helm uninstall cluster-autoscaler -n kube-system
```

### 2. Scale Down Existing Node Groups
If migrating from ASG-based nodes:

```bash
# Gradually reduce ASG minimums
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name <asg-name> \
  --min-size 0 \
  --desired-capacity 0
```

### 3. Monitor Cost Savings
Track instance costs in AWS Cost Explorer with tag filter:
```
facets:component = karpenter
```

## Troubleshooting

### Nodes not being created

Check:
1. **Subnet tags**: `karpenter.sh/discovery=<cluster-name>`
2. **Security group tags**: `karpenter.sh/discovery=<cluster-name>`
3. **NodePool limits**: Not exceeded
4. **IAM permissions**: Controller role has correct policies

View detailed errors:
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter | grep ERROR
```

### Insufficient capacity errors

If seeing "InsufficientInstanceCapacity":
1. Add more instance families to node pool
2. Add more instance sizes
3. Enable multiple availability zones
4. Mix Spot and On-Demand

### Consolidation not working

Check:
1. `enable_consolidation: true` in spec
2. Pods have appropriate PodDisruptionBudgets
3. No pods with local storage
4. No DaemonSets blocking

## Performance Tuning

### For Batch Workloads
```yaml
node_pools:
  batch:
    instance_families: [c5, c5a, c6i, c5n]  # More options
    capacity_types: [spot]  # Spot only for batch
    enable_consolidation: true
```

### For Stable Services
```yaml
node_pools:
  services:
    instance_families: [t3, t3a]
    capacity_types: [on-demand]  # On-demand for stability
    enable_consolidation: false  # Less disruption
```

### For ML/GPU Workloads
```yaml
node_pools:
  gpu:
    instance_families: [p3, p4, g4dn]
    capacity_types: [on-demand]
    labels:
      accelerator: nvidia
```

## Monitoring

### Key Metrics to Watch

```promql
# Node provisioning rate
rate(karpenter_nodes_created[5m])

# Node termination rate
rate(karpenter_nodes_terminated[5m])

# Pod startup latency
histogram_quantile(0.95, karpenter_pods_startup_duration_seconds)

# Consolidation actions
karpenter_consolidation_actions_performed
```

### CloudWatch Dashboard

Create dashboard with:
- Active nodes by node pool
- Pod scheduling latency
- Interruption events
- Cost per node pool

## Best Practices

1. **Start Conservative**: Begin with On-Demand, add Spot gradually
2. **Multiple Instance Types**: More options = better availability
3. **Set Realistic Limits**: Prevent runaway costs
4. **Use Labels**: Organize workloads by node pool
5. **Monitor Costs**: Track spending by node pool
6. **Test Interruptions**: Verify graceful handling
7. **Regular Updates**: Keep Karpenter version current

## Additional Resources

- [Karpenter Official Docs](https://karpenter.sh/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/karpenter/)
- [Karpenter Workshop](https://www.eksworkshop.com/docs/autoscaling/compute/karpenter/)
