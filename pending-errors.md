# Pending Module Validation Errors

Generated: 2026-01-08 (after commit 04b9a51)

## Summary

| Status | Count |
|--------|-------|
| ✅ Passed | 17 |
| ❌ Failed | 20 |

---

## Passed Modules (17)

1. `cloud_account/aws_provider` ✅
2. `cloud_account/azure_provider` ✅ (fixed in e53ab3e - missing sample.spec field)
3. `cloud_account/gcp_provider` ✅
4. `common/config_map/k8s_standard` ✅
5. `common/helm/k8s_standard` ✅
6. `common/k8s_resource/k8s_standard` ✅
7. `common/kubernetes_secret/k8s_standard` ✅
8. `common/vpa/standard` ✅
9. `kubernetes_node_pool/aws` ✅
10. `kubernetes_node_pool/azure` ✅ (fixed in 3f78397 - var.inputs)
11. `kubernetes_node_pool/gcp_node_fleet` ✅ (fixed in 04b9a51 - schema mismatch, wrong input source)
12. `network/azure_network` ✅
13. `network/gcp_vpc` ✅ (var.inputs fixed in 04b9a51, Trivy fails - pre-existing)
14. `pubsub/gcp` ✅ (fixed in 04b9a51 - var.inputs)
15. `workload_identity/azure` ✅ (fixed in 04b9a51 - missing cloud_account, flat structure)
16. `workload_identity/gcp` ✅ (fixed in 04b9a51 - missing cloud_account, schema parse error)

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

**Notes:** These pass all other validations (TF init, TF validate, facets.yaml, var.inputs). Security issues need review.

---

### Category B: Non-existent Output Type (8 modules)

| Module | Missing Output Type | Issue # |
|--------|---------------------|---------|
| `common/eck-operator/helm` | `@facets/kubernetes-cluster` (input) | #18 (pending-errors) |
| `common/grafana_dashboards/k8s` | `@facets/grafana_dashboards` (output) | #18 (pending-errors) |
| `common/kubeblocks-crd/standard` | `@facets/kubernetes-cluster` (input) | #18 (pending-errors) |
| `common/monitoring/mongo` | `@facets/monitoring-rules` (output) | #18 (pending-errors) |
| `common/strimzi-operator/helm` | `@facets/kubernetes-cluster` (input) | #18 (pending-errors) |
| `common/wireguard-operator/standard` | `@facets/wireguard-details` (output) | #18 (pending-errors) |
| `common/wireguard-vpn/standard` | `@facets/wireguard-details` (input) | #18 (pending-errors) |

**Root Cause:** These output types don't exist in the control plane. Either:
1. Output types need to be registered in CP
2. facets.yaml references are incorrect

---

### Category C: var.inputs Schema Mismatch (1 module)

| Module | Error | Issue # |
|--------|-------|---------|
| `common/kubeblocks-operator/standard` | node_pool.attributes.node_selector: expected string, got map | #19 (pending-errors) |

**Notes:** Schema mismatch - var.inputs type doesn't match output-type schema

---

### Category D: Provider Not Found (4 modules)

| Module | Missing Provider | Issue # |
|--------|------------------|---------|
| `common/cert_manager/standard` | hashicorp/aws3tooling | #15 |
| `common/ingress/nginx_k8s` | hashicorp/aws3tooling | #15 |
| `service/azure` | hashicorp/facets | #15 |
| `service/gcp` | hashicorp/facets | #15 |

**Root Cause:**
- Provider alias `aws3tooling` is interpreted as `hashicorp/aws3tooling` which doesn't exist
- `facets` provider requires `Facets-cloud/facets` source but can't define `required_providers`

---

### Category E: Terraform Validation Errors (4 modules)

| Module | Error | Issue # |
|--------|-------|---------|
| `common/artifactories/standard` | no file exists at "../deploymentcontext.json" | #10 |
| `common/k8s_callback/k8s_standard` | undeclared variables (4 errors) | #10 |
| `common/prometheus/k8s_standard` | undeclared variables (4 errors) | #10 |
| `service/aws` | TF validate: 9 errors (undeclared cc_metadata, inconsistent conditionals) | #10 |

---

## Fixed Modules (since last report)

### Fixed in commit 04b9a51

| Module | Error Type | Root Cause | Fix Applied |
|--------|------------|------------|-------------|
| `workload_identity/gcp` | Schema parse error + missing input | @facets/gke had nested exec object; missing cloud_account | Removed exec from output schema; added cloud_account to var.inputs |
| `workload_identity/azure` | Missing input + flat structure | Missing cloud_account; aks_cluster used flat structure | Added cloud_account; converted to attributes/interfaces pattern |
| `service/azure` | Missing inputs | Missing cloud_account, network_details, kubernetes_node_pool_details | Added all 3 missing inputs with proper schemas |
| `kubernetes_node_pool/gcp_node_fleet` | TF validate error | Module accessed project_id/region from wrong input (cloud_account vs kubernetes_details) | Changed to use kubernetes_details.attributes |
| `pubsub/gcp` | var.inputs schema | Had deprecated 'project' field | Updated to use project_id, region |
| `network/gcp_vpc` | var.inputs schema | Had deprecated 'project' field | Updated to use project_id, region |
| `kubernetes_node_pool/gcp` | var.inputs schema | Had deprecated 'project' field | Updated to use project_id, region |

### Output Type Schema Updates in commit 04b9a51

| Output Type | Change |
|-------------|--------|
| `@facets/gcp_cloud_account` | Added `project_id`, `region`; removed deprecated `project` |
| `@facets/gke` | Removed nested `exec` object from `interfaces.kubernetes` |

---

## New Issues Discovered

### Issue #18: Non-existent Output Type References (from pending-errors)

**Error Pattern:**
```
facets.yaml validation failed: Input/Output type validation failed:
  - input/output 'X' references non-existent output type '@facets/Y': output type does not exist
```

**Modules Affected:** 7 modules

**Missing Output Types:**
- `@facets/kubernetes-cluster` (3 modules)
- `@facets/grafana_dashboards`
- `@facets/monitoring-rules`
- `@facets/wireguard-details` (2 modules)

**Fix:** Register these output types in control plane, or fix references in facets.yaml

---

### Issue #19: var.inputs Type vs Output-Type Schema Mismatch (from pending-errors)

**Error Pattern:**
```
var.inputs validation failed:
  - var.inputs.X does not match output-type schema '@facets/Y': at X.attributes.Z: expected string, got list/map
```

**Modules Affected:** 1 module
- `common/kubeblocks-operator/standard` - node_selector: expected string, got map

**Root Cause:** The output type schema in CP defines the attribute as `string`, but module declares it as `map`.

**Fix Options:**
1. Update output type schema in CP to use correct type
2. Update var.inputs in module to use `string` (then parse in code)

---

## Summary by Issue Type

| Issue Type | Count | Status |
|------------|-------|--------|
| Security scan failures | 6 | #16 - ACTIVE |
| Non-existent output type | 7 | #18 (pending-errors) |
| var.inputs schema mismatch | 1 | #19 (pending-errors) |
| Provider not found | 4 | #15 - ACTIVE |
| TF validation errors | 4 | #10 - ACTIVE |

---

## Changes from Previous Run

**Newly Passing (5 modules):**
1. `kubernetes_node_pool/gcp_node_fleet` - Fixed schema mismatch, wrong input source (04b9a51)
2. `pubsub/gcp` - Fixed var.inputs schema (04b9a51)
3. `workload_identity/azure` - Fixed missing cloud_account, flat structure (04b9a51)
4. `workload_identity/gcp` - Fixed missing cloud_account, schema parse error (04b9a51)
5. `network/gcp_vpc` - Fixed var.inputs schema (04b9a51)

**Newly Failing (0 modules):**
None - all failures existed before

**Status Changes:**
- Previous: 12 passed, 25 failed (after commit 3f78397)
- Current: 17 passed, 20 failed (after commit 04b9a51)
- Net improvement: +5 passing modules

---

## Priority Fix Order

1. **Output Type Registration** (7 modules) - Register missing output types in CP
2. **Output Type Schema Fixes** (1 module) - Fix type definitions in output schemas
3. **Provider Issues** (4 modules) - Handle aws3tooling and facets provider aliases
4. **TF Validation Errors** (4 modules) - Fix undeclared variables, missing files
5. **Security Scan** (6 modules) - Review and address HIGH/CRITICAL issues

---

## Historical Changes

### 2026-01-08 (commit 04b9a51)
- Fixed 5 modules: gcp_node_fleet, pubsub/gcp, workload_identity/azure, workload_identity/gcp, network/gcp_vpc
- Updated @facets/gcp_cloud_account schema: added project_id, region; removed deprecated project
- Updated @facets/gke schema: removed nested exec object from interfaces

### 2026-01-08 (commit 3f78397)
- Fixed 2 modules: kubernetes_node_pool/azure, pubsub/gcp (partial)
- Added missing attributes to var.inputs type definitions

### 2026-01-07 (commit 30c3956)
- Fixed 2 modules: workload_identity/azure, workload_identity/gcp (partial)
- Added explicit spec type for workload_identity modules
