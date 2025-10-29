# KubeBlocks Operator Module

This module deploys the KubeBlocks operator (v0.9.5) on Kubernetes, along with optional database addons for PostgreSQL, MySQL, MongoDB, Redis, and Kafka.

## Features

- **KubeBlocks Operator**: Core operator for managing database clusters on Kubernetes
- **CRD Management**: Installs and waits for Custom Resource Definitions to be fully established
- **Database Addons**: Optional installation of database-specific ClusterDefinitions and ComponentDefinitions via Helm releases
- **Terraform Lifecycle**: Resources managed through Terraform state with proper dependency handling

## Database Addons

Enable database addons by setting the corresponding flags in `database_addons`:

```yaml
database_addons:
  postgresql: true   # Install PostgreSQL addon (chart v0.9.5)
  mysql: true        # Install MySQL addon (chart v0.9.3)
  mongodb: true      # Install MongoDB addon (chart v0.9.3)
  redis: true        # Install Redis addon (chart v0.9.7)
  kafka: true        # Install Kafka addon (chart v0.9.1)
```

Each enabled addon is deployed as a separate Terraform-managed Helm release (`kb-addon-<name>`).

## Deployment

```bash
terraform init
terraform plan
terraform apply
```

The deployment process:
1. Creates `kb-system` namespace
2. Installs KubeBlocks CRDs and waits for them to reach "Established" status
3. Deploys KubeBlocks operator via Helm
4. Installs enabled database addons as separate Helm releases

## ⚠️ IMPORTANT: Manual Cleanup Required Before Destroy

**Terraform destroy WILL HANG indefinitely without manual cleanup.**

The KubeBlocks operator creates cluster-scoped Addon CRs via admission webhooks that are NOT managed by Terraform or Helm. These resources will block namespace deletion, causing `terraform destroy` to hang.

### Why Automatic Cleanup Doesn't Work

1. **Addon CRs are cluster-scoped**: The operator creates 19 Addon custom resources at the cluster level (not namespace level) via admission webhooks. Terraform has no visibility or control over these.

2. **Timing issues**: By the time Terraform tries to delete the namespace, the operator controllers are already being terminated, so finalizers cannot be processed properly.

3. **ConfigMaps kept by Helm**: The Helm resource policy keeps ConfigMaps even after release deletion, blocking namespace cleanup.

4. **Terraform destroy order**: Terraform cannot control the destroy order for cluster-scoped resources that block namespace deletion. Local-exec provisioners run too late (after operator is deleted) to be effective.

### Required Manual Cleanup Steps

**Run these commands BEFORE executing `terraform destroy`:**

```bash
# Step 1: Delete all Addon CRs (cluster-scoped resources created by operator webhook)
# This removes the 19 addon resources that block namespace deletion
kubectl delete addons.extensions.kubeblocks.io --all --force --grace-period=0

# Step 2: Patch leftover ConfigMaps (kept by Helm resource policy)
# These ConfigMaps prevent namespace from being deleted cleanly
kubectl get configmaps -n kb-system -l app.kubernetes.io/managed-by=Helm -o name | xargs -I {} kubectl patch {} -n kb-system -p '{"metadata":{"finalizers":[]}}' --type=merge

# Step 3: Patch CRD finalizers (prevents stuck CRD deletion)
# Finalizers can cause CRDs to hang during deletion if operator is already gone
kubectl get crd -l app.kubernetes.io/name=kubeblocks -o name | \
  xargs -I {} kubectl patch {} --type merge -p '{"metadata":{"finalizers":[]}}'

# Step 4: Now run terraform destroy
terraform destroy
```

### Alternative: Remove from State First

If you want to clean up manually without Terraform tracking:

```bash
# Remove module from Terraform state
terraform state rm 'module.kubeblocks_operator'

# Then perform manual cleanup
kubectl delete addons.extensions.kubeblocks.io --all --force --grace-period=0
kubectl delete namespace kb-system --force --grace-period=0
kubectl get crd -l app.kubernetes.io/name=kubeblocks -o name | \
  xargs -I {} kubectl delete {} --force --grace-period=0
```

## Troubleshooting

### Issue: `terraform destroy` hangs on "Still destroying..."

**Cause**: Addon CRs or ConfigMaps are blocking namespace deletion.

**Solution**: Follow the manual cleanup steps above, then retry destroy.

### Issue: CRDs stuck in "Terminating" state

**Cause**: CRD finalizers cannot be processed because operator controllers are already deleted.

**Solution**: Patch finalizers to empty array:
```bash
kubectl get crd -l app.kubernetes.io/name=kubeblocks -o name | \
  xargs -I {} kubectl patch {} --type merge -p '{"metadata":{"finalizers":[]}}'
```

### Issue: Namespace stuck in "Terminating" state

**Cause**: Resources with finalizers still exist in the namespace.

**Solution**: 
```bash
# Check what's blocking
kubectl api-resources --verbs=list --namespaced -o name | \
  xargs -n 1 kubectl get --show-kind --ignore-not-found -n kb-system

# Force delete blocking resources
kubectl delete addons.extensions.kubeblocks.io --all --force --grace-period=0
kubectl delete cm -n kb-system --all --force --grace-period=0

# Patch namespace finalizers if still stuck
kubectl patch namespace kb-system -p '{"metadata":{"finalizers":[]}}' --type=merge
```

### Issue: "Release not loaded: kubeblocks: release: not found"

**Cause**: Manual cleanup deleted Helm releases that Terraform still tracks in state.

**Solution**: Remove from state before destroy:
```bash
terraform state rm 'helm_release.kubeblocks'
terraform state rm 'helm_release.database_addons["postgresql"]'
# etc. for other addons
```

## Deployment Workflow Example

```bash
# 1. Initial deployment
terraform apply

# 2. Deploy database clusters using installed addons
# (e.g., postgresql-cluster module)

# 3. When ready to destroy:

# 3a. First destroy database clusters
cd ../postgresql-cluster
terraform destroy

# 3b. Then manually cleanup KubeBlocks resources
kubectl delete addons.extensions.kubeblocks.io --all --force --grace-period=0
kubectl delete cm -n kb-system -l app.kubernetes.io/managed-by=Helm
kubectl get crd -l app.kubernetes.io/name=kubeblocks -o name | \
  xargs -I {} kubectl patch {} --type merge -p '{"metadata":{"finalizers":[]}}'

# 3c. Finally destroy operator
cd ../kubeblocks-operator
terraform destroy
```

## Module Configuration

### Inputs

- `instance.spec.database_addons`: Object with boolean flags for each database addon (postgresql, mysql, mongodb, redis, kafka)

### Outputs

- `kubeblocks_namespace`: Name of the KubeBlocks namespace (kb-system)
- `kubeblocks_version`: Version of KubeBlocks operator installed (0.9.5)
- `enabled_addons`: List of enabled database addons

## Technical Details

- **KubeBlocks Version**: 0.9.5
- **Helm Chart**: `apecloud/kubeblocks`
- **Namespace**: `kb-system`
- **CRD Wait Condition**: Waits for "Established" status before proceeding
- **Addon Controller**: Disabled (addons managed via database_addons instead)
- **Helm Release Timeout**: 10 minutes for operator, 10 minutes for each addon

## Known Limitations

1. **Manual cleanup required**: Automatic cleanup during `terraform destroy` is not possible due to cluster-scoped Addon CRs created by operator webhooks.

2. **Finalizer timing issues**: If operator is deleted before Addon CRs are removed, finalizers cannot be processed, causing stuck resources.

3. **No state tracking for webhook-created resources**: The 19 Addon CRs created by the operator admission webhook are not tracked by Terraform or Helm.

4. **ConfigMap retention**: Helm resource policy keeps ConfigMaps after release deletion, requiring manual cleanup.

## References

- [KubeBlocks Documentation](https://kubeblocks.io/)
- [KubeBlocks GitHub](https://github.com/apecloud/kubeblocks)
- [KubeBlocks Helm Charts](https://github.com/apecloud/helm-charts)
