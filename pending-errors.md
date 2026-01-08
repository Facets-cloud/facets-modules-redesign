# Pending Module Validation Errors

Generated: 2026-01-08 (after commit 3f78397)

## Summary

| Status | Count |
|--------|-------|
| ✅ Passed | 12 |
| ❌ Failed | 25 |

---

## Passed Modules (12)

1. `cloud_account/aws_provider` ✅
2. `cloud_account/azure_provider` ✅ (NEW - was failing with missing sample.spec field)
3. `cloud_account/gcp_provider` ✅
4. `common/config_map/k8s_standard` ✅
5. `common/helm/k8s_standard` ✅
6. `common/k8s_resource/k8s_standard` ✅
7. `common/kubernetes_secret/k8s_standard` ✅
8. `common/vpa/standard` ✅
9. `kubernetes_node_pool/aws` ✅
10. `kubernetes_node_pool/azure` ✅ (NEW - fixed var.inputs in 3f78397)
11. `network/azure_network` ✅
12. `pubsub/gcp` ✅ (NEW - fixed var.inputs in 3f78397)

---

## Failed Modules by Error Category

### Category A: Security Scan Failures (6 modules)

| Module | Issue Count | Issue # |
|--------|-------------|---------|
| `kubernetes_cluster/aks` | 9 HIGH/CRITICAL | #16 |
| `kubernetes_cluster/eks` | 13 HIGH/CRITICAL | #16 |
| `kubernetes_cluster/gke` | 1 HIGH/CRITICAL | #16 |
| `kubernetes_node_pool/gcp` | 1 HIGH/CRITICAL | #16 |
| `network/aws_vpc` | 1 HIGH/CRITICAL | #16 |
| `network/gcp_vpc` | 1 HIGH/CRITICAL | #16 |

**Notes:** These pass all other validations (TF init, TF validate, facets.yaml). Security issues need review.

---

### Category B: Non-existent Output Type (8 modules)

| Module | Missing Output Type | Issue # |
|--------|---------------------|---------|
| `common/eck-operator/helm` | `@facets/kubernetes-cluster` (input) | NEW #18 |
| `common/grafana_dashboards/k8s` | `@facets/grafana_dashboards` (output) | NEW #18 |
| `common/kubeblocks-crd/standard` | `@facets/kubernetes-cluster` (input) | NEW #18 |
| `common/monitoring/mongo` | `@facets/monitoring-rules` (output) | NEW #18 |
| `common/strimzi-operator/helm` | `@facets/kubernetes-cluster` (input) | NEW #18 |
| `common/wireguard-operator/standard` | `@facets/wireguard-details` (output) | NEW #18 |
| `common/wireguard-vpn/standard` | `@facets/wireguard-details` (input) | NEW #18 |
| `workload_identity/azure` | `@facets/azure_workload_identity` (output) | NEW #18 |

**Root Cause:** These output types don't exist in the control plane. Either:
1. Output types need to be registered in CP
2. facets.yaml references are incorrect

---

### Category C: var.inputs Missing Fields (3 modules)

| Module | Error | Issue # |
|--------|-------|---------|
| `workload_identity/gcp` | input 'cloud_account' defined in facets.yaml but not declared in var.inputs | #6 |
| `common/kubeblocks-operator/standard` | node_pool.attributes.node_selector: expected string, got map | NEW #19 |
| `kubernetes_cluster/aks` | network_details.attributes.private_subnet_ids: expected string, got list | NEW #19 |

**Notes:**
- `workload_identity/gcp`: Needs cloud_account added to var.inputs
- Schema mismatch issues: var.inputs type doesn't match output-type schema

---

### Category D: var.inputs Schema Mismatch (3 modules)

| Module | Error | Issue # |
|--------|-------|---------|
| `service/azure` | artifactories.attributes.registry_secrets_list: expected string, got list | NEW #19 |
| `service/gcp` | artifactories.attributes.registry_secret_objects: expected string, got map | NEW #19 |
| `service/azure` | Also missing: network_details, cloud_account, kubernetes_node_pool_details | #6 |

**Root Cause:** The module's var.inputs type has `list` or `map` types where the output type schema expects `string`.

---

### Category E: Provider Not Found (2 modules)

| Module | Missing Provider | Issue # |
|--------|------------------|---------|
| `common/cert_manager/standard` | hashicorp/aws3tooling | #15 |
| `common/ingress/nginx_k8s` | hashicorp/aws3tooling | #15 |

**Root Cause:** Provider alias `aws3tooling` is interpreted as `hashicorp/aws3tooling` which doesn't exist.

---

### Category F: Terraform Validation Errors (3 modules)

| Module | Error | Issue # |
|--------|-------|---------|
| `common/artifactories/standard` | no file exists at "../deploymentcontext.json" | #10 |
| `common/k8s_callback/k8s_standard` | undeclared variables (4 errors) | #10 |
| `common/prometheus/k8s_standard` | undeclared variables (4 errors) | #10 |

---

### Category G: Terraform Validation - Multiple Errors (2 modules)

| Module | Errors | Issue # |
|--------|--------|---------|
| `kubernetes_node_pool/gcp_node_fleet` | TF validate: 2 errors | NEW |
| `service/aws` | TF validate: 9 errors (undeclared cc_metadata, inconsistent conditionals) | #10 |

---

## New Issues Discovered (vs issues.md)

### NEW Issue #18: Non-existent Output Type References

**Error Pattern:**
```
facets.yaml validation failed: Input/Output type validation failed:
  - input/output 'X' references non-existent output type '@facets/Y': output type does not exist
```

**Modules Affected:** 8 modules

**Missing Output Types:**
- `@facets/kubernetes-cluster`
- `@facets/grafana_dashboards`
- `@facets/monitoring-rules`
- `@facets/wireguard-details`
- `@facets/azure_workload_identity`

**Fix:** Register these output types in control plane, or fix references in facets.yaml

---

### NEW Issue #19: var.inputs Type vs Output-Type Schema Mismatch

**Error Pattern:**
```
var.inputs validation failed:
  - var.inputs.X does not match output-type schema '@facets/Y': at X.attributes.Z: expected string, got list/map
```

**Modules Affected:** 4 modules
- `kubernetes_cluster/aks` - private_subnet_ids: expected string, got list
- `common/kubeblocks-operator/standard` - node_selector: expected string, got map
- `service/azure` - registry_secrets_list: expected string, got list
- `service/gcp` - registry_secret_objects: expected string, got map

**Root Cause:** The output type schema in CP defines these attributes as `string`, but modules declare them as `list` or `map`.

**Fix Options:**
1. Update output type schema in CP to use correct types
2. Update var.inputs in modules to use `string` (then parse in code)

---

## Summary by Issue Type

| Issue Type | Count | Status |
|------------|-------|--------|
| Security scan failures | 6 | #16 - ACTIVE |
| Non-existent output type | 8 | NEW #18 |
| var.inputs missing fields | 1 | #6 - needs fix |
| var.inputs schema mismatch | 4 | NEW #19 |
| Provider not found | 2 | #15 - ACTIVE |
| TF validation errors | 5 | #10 - ACTIVE |

---

## Changes from Previous Run

**Newly Passing (3 modules):**
1. `cloud_account/azure_provider` - sample.spec was fixed
2. `kubernetes_node_pool/azure` - var.inputs fixed in commit 3f78397
3. `pubsub/gcp` - var.inputs fixed in commit 3f78397

**Newly Failing (0 modules):**
None - all failures existed before

**Status Changes:**
- Previous: 10 passed, 27 failed (after commit 30c3956)
- Current: 12 passed, 25 failed (after commit 3f78397)
- Net improvement: +2 passing modules

---

## Priority Fix Order

1. **Output Type Registration** (8 modules) - Register missing output types in CP
2. **Output Type Schema Fixes** (4 modules) - Fix type definitions in output schemas
3. **var.inputs Missing Fields** (1 module) - Add cloud_account to workload_identity/gcp
4. **Provider Issues** (2 modules) - Handle aws3tooling provider alias
5. **TF Validation Errors** (5 modules) - Fix undeclared variables, missing files
6. **Security Scan** (6 modules) - Review and address HIGH/CRITICAL issues
