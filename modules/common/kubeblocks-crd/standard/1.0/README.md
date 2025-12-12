# KubeBlocks CRDs Module

## Overview

This module installs the **KubeBlocks Custom Resource Definitions (CRDs)** on a Kubernetes cluster. KubeBlocks CRDs define all API types required by the KubeBlocks operator to manage stateful data services such as PostgreSQL, MySQL, Redis, MongoDB, Kafka, and more.

This module is designed specifically to handle **large CRD files (>5MB)** that cannot be installed through Helm due to release metadata storage limitations (1MB limit).

> **Default Version: `1.0.1`**
> 
> This module is tested, validated, and fully compatible with KubeBlocks **v1.0.1**, which should be used by default across all Facets modules.
>
> It forms the base of the dependency chain:
> **kubeblocks-crd → kubeblocks-operator → addons (Redis, PostgreSQL, MySQL, etc.)**

---

## Key Features

### ✅ Direct CRD Management
- Uses `kubernetes_manifest` resource with `for_each` to apply individual CRDs
- Downloads CRDs directly from KubeBlocks GitHub releases
- Automatically splits multi-document YAML into individual CRD resources
- No Helm storage limitations

### ✅ Proper Lifecycle Management
- **Wait conditions**: Ensures each CRD reaches "Established" status before completion
- **Computed fields**: Properly handles server-managed fields (finalizers, status, resourceVersion)
- **Force conflicts**: Uses field manager to handle conflicts during apply
- **Timeouts**: 10-minute timeouts for create/delete operations
- **Destruction enabled**: Allows clean teardown when needed

### ✅ Release Tracking
- Generates unique `release_id` based on version and CRD count
- Used by dependent modules (kubeblocks-operator) to ensure proper sequencing
- Automatically regenerates when version or CRD count changes

---

## Architecture Changes

This version (1.0) implements a **simplified and robust architecture** compared to previous iterations:

### Previous Approach (Deprecated)
- Complex dependency tracking with multiple IDs
- Kubernetes Job-based installation with kubectl apply
- Manual cleanup with null_resource and local-exec
- Annotation-based dependency injection
- Complicated state management

### Current Approach (Recommended)
- **Direct Terraform resource management** using `kubernetes_manifest`
- Built-in Kubernetes provider lifecycle management
- Automatic CRD splitting and parallel installation
- Simple `release_id` for dependency tracking
- Clean destruction without manual cleanup scripts

**Benefits:**
- More reliable and idempotent
- Better error handling and reporting
- Faster installation (parallel CRD application)
- Cleaner Terraform state
- No external script dependencies

---

## Environment as Dimension

This module is **environment-agnostic**:

* CRDs are **cluster-scoped**, not namespaced
* The same CRD version (`1.0.1`) is applied consistently across all environments: dev, stage, prod
* No environment-specific configuration is needed

Because CRDs define API types (not workloads), they must be identical in all environments to ensure operator/API compatibility.

---

## Resources Created

### 1. KubeBlocks Custom Resource Definitions

All CRDs included in the official KubeBlocks v1.0.1 release bundle:

* `Cluster`
* `ComponentDefinition`
* `ClusterDefinition`
* `OpsRequest`
* `ClusterBackup`
* `ClusterRestore`
* `BackupPolicy`
* `BackupSchedule`
* `Addon`
* `ActionSet`
* `ConfigConstraint`
* And more (full list depends on v1.0.1 release)

CRDs are pulled directly from: `https://github.com/apecloud/kubeblocks/releases/download/v1.0.1/kubeblocks_crds.yaml`

### 2. Release Tracking Resource

A `random_uuid` resource that generates:
- `release_id`: Unique identifier for this CRD deployment

The UUID is regenerated when:
- KubeBlocks version changes
- Number of CRDs changes

---

## Module Dependencies

This module must be applied **first** in the KubeBlocks dependency chain.

### Dependency Chain

```text
1. kubeblocks-crd        (this module - installs CRDs)
   ↓
2. kubeblocks-operator   (installs operator that uses CRDs)
   ↓
3. kubeblocks-addons     (Redis, PostgreSQL, MySQL, MongoDB, Kafka, etc.)
```

The KubeBlocks operator **will not start** unless these CRDs are already installed. Addon modules depend on the operator and indirectly on these CRDs.

---

## Outputs

The module outputs the following attributes:

| Output | Type | Description |
|--------|------|-------------|
| `version` | string | KubeBlocks version for which CRDs were installed |
| `crds_count` | number | Total number of CRDs successfully installed |
| `release_id` | string | Unique UUID for this CRD deployment |

The `release_id` can be consumed by the `kubeblocks-operator` module to establish proper dependency ordering.

---

## CRD Management Strategy

### Why Not Helm?

CRDs are installed using **`kubernetes_manifest`** instead of Helm because:

* Many KubeBlocks CRDs exceed **5 MB** in size
* Helm has a **1MB limit** on release metadata storage in Secrets/ConfigMaps
* Large CRDs cause Helm to fail with "metadata too large" errors
* Direct Kubernetes API calls avoid this limitation entirely
* Terraform's native Kubernetes provider handles CRDs properly

### Why For-Each?

The module splits the multi-document YAML into individual CRDs and applies them using `for_each`:

* **Parallel installation**: Multiple CRDs can be created concurrently
* **Better error isolation**: If one CRD fails, others still succeed
* **Granular state management**: Each CRD is tracked separately in Terraform state
* **Easier debugging**: Clear identification of which CRD failed

### Computed Fields

The module explicitly ignores server-managed fields:

```hcl
computed_fields = [
  "metadata.finalizers",
  "metadata.generation",
  "metadata.resourceVersion",
  "status"
]
```

This prevents Terraform from trying to manage fields that Kubernetes controllers update automatically.

---

## Version Management

### Current Version: `1.0.1` (Default & Recommended)

This version is:
- Thoroughly tested across all Facets modules
- Compatible with:
  - `kubeblocks-operator v1.0.1`
  - All official addons released for v1.0.1
  - Facets Terraform modules (`redis`, `postgres`, `mysql`, etc.)

### Upgrading

To upgrade to a different KubeBlocks version:

1. Update the `version` field in your module spec:
   ```yaml
   spec:
     version: "1.0.2"  # or desired version
   ```

2. The module will automatically:
   - Fetch CRDs for the new version from GitHub
   - Apply any new or updated CRDs
   - Regenerate `release_id` (triggering dependent module updates)

3. Ensure the new version is compatible with your operator and addon versions

---

## Destruction and Cleanup

This module now supports **clean destruction** through Terraform:

```bash
terraform destroy
```

The `kubernetes_manifest` resources will:
- Remove all CRDs from the cluster
- Wait up to 10 minutes for graceful deletion
- Handle finalizers automatically

**Important**: Destroying CRDs will:
- Remove all custom resources (Clusters, Backups, etc.)
- Make the KubeBlocks operator non-functional
- Require reinstallation of dependent modules

Always destroy in reverse dependency order:
1. Remove addon modules first (Redis, PostgreSQL, etc.)
2. Remove kubeblocks-operator
3. Remove kubeblocks-crd (this module)

---

## Security Considerations

* CRDs are **cluster-scoped**, so they require elevated permissions to install
* Ensure only cluster administrators can apply or modify CRDs
* CRDs define API surfaces for databases—incorrect or incompatible CRD versions can break operator functionality
* RBAC policies should restrict who can create or modify the new resources defined by these CRDs
* The module requires Kubernetes provider credentials with cluster-admin level access

---

## Troubleshooting

### CRD Installation Fails

**Error**: `timeout while waiting for condition 'Established'`

**Solution**: 
- Check Kubernetes API server health
- Verify network connectivity to cluster
- Increase timeout values if cluster is slow
- Check API server logs for validation errors

### CRDs Not Found After Installation

**Error**: `the server could not find the requested resource`

**Solution**:
- Verify CRDs are installed: `kubectl get crds | grep kubeblocks`
- Check CRD status: `kubectl get crd <crd-name> -o yaml`
- Ensure CRDs reached "Established" condition
- Check the `crds_count` output matches expected number

### Destruction Hangs

**Error**: `terraform destroy` hangs on CRD deletion

**Solution**:
- Check for finalizers on custom resources: `kubectl get clusters -A`
- Manually remove custom resources before destroying CRDs
- Remove finalizers if stuck: `kubectl patch <resource> -p '{"metadata":{"finalizers":[]}}' --type=merge`
- Increase delete timeout if needed

### Version Mismatch

**Error**: Operator complains about CRD version mismatch

**Solution**:
- Ensure CRD version matches operator version (both should be v1.0.1)
- Upgrade CRDs before upgrading operator
- Check KubeBlocks release notes for compatibility matrix

---

## Examples

### Basic Usage

```yaml
kind: kubeblocks-crd
flavor: standard
version: '1.0'
spec:
  version: "1.0.1"
```

### Using in Dependent Modules

The kubeblocks-operator module can reference this module's outputs:

```hcl
# In kubeblocks-operator module
variable "kubeblocks_crd" {
  type = object({
    release_id = string
    version    = string
  })
}

# This creates an implicit dependency
resource "random_uuid" "operator_dependency" {
  keepers = {
    crd_release_id = var.kubeblocks_crd.release_id
  }
}
```

---

## Module Information

- **Intent**: kubeblocks-crd
- **Flavor**: standard
- **Version**: 1.0
- **Cloud**: Kubernetes
- **Tested with**: KubeBlocks v1.0.1
- **Terraform Provider**: hashicorp/kubernetes >= 2.0

---

## Support

For issues or questions:
- Check KubeBlocks documentation: https://kubeblocks.io
- Review Terraform Kubernetes provider docs
- Check Facets internal documentation
- Contact the platform team
