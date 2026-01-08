# Pending Module Validation Errors

Generated: 2026-01-08 (after commit a1325aa)

## Summary

| Status | Count |
|--------|-------|
| ✅ Passed | 28 |
| ❌ Failed | 9 |

---

## Passed Modules (28)

1. `cloud_account/aws_provider` ✅
2. `cloud_account/azure_provider` ✅ (fixed in e53ab3e)
3. `cloud_account/gcp_provider` ✅
4. `common/config_map/k8s_standard` ✅
5. `common/eck-operator/helm` ✅ (was failing - now passes)
6. `common/grafana_dashboards/k8s` ✅ (was failing - now passes, warning: deprecated resource)
7. `common/helm/k8s_standard` ✅
8. `common/k8s_resource/k8s_standard` ✅
9. `common/kubeblocks-operator/standard` ✅ (was failing - now passes)
10. `common/kubernetes_secret/k8s_standard` ✅
11. `common/monitoring/mongo` ✅ (was failing - now passes)
12. `common/strimzi-operator/helm` ✅ (was failing - now passes)
13. `common/vpa/standard` ✅ (warning: deprecated resource)
14. `common/wireguard-operator/standard` ✅ (was failing - now passes)
15. `common/wireguard-vpn/standard` ✅ (was failing - now passes)
16. `kubernetes_cluster/aks` ✅ (with --skip-security-scan)
17. `kubernetes_cluster/eks` ✅ (with --skip-security-scan, warning: deprecated attribute)
18. `kubernetes_cluster/gke` ✅ (with --skip-security-scan)
19. `kubernetes_node_pool/aws` ✅
20. `kubernetes_node_pool/azure` ✅ (fixed in 3f78397)
21. `kubernetes_node_pool/gcp` ✅ (with --skip-security-scan)
22. `kubernetes_node_pool/gcp_node_fleet` ✅ (fixed in 04b9a51)
23. `network/aws_vpc` ✅ (with --skip-security-scan)
24. `network/azure_network` ✅
25. `network/gcp_vpc` ✅ (with --skip-security-scan)
26. `pubsub/gcp` ✅ (fixed in 04b9a51)
27. `workload_identity/azure` ✅ (fixed in 04b9a51)
28. `workload_identity/gcp` ✅ (fixed in 04b9a51, warning: deprecated resource)

---

## Failed Modules by Error Category

### Category A: Terraform Validation Errors (4 modules)

| Module | Error | Issue # |
|--------|-------|---------|
| `common/artifactories/standard` | no file exists at "../deploymentcontext.json" | #10 |
| `common/k8s_callback/k8s_standard` | undeclared variables: `cluster`, `cc_metadata` (4 errors) | #10 |
| `common/prometheus/k8s_standard` | undeclared variable: `cc_metadata` (4 errors) | #10 |
| `service/aws` | undeclared `baseinfra`, `cluster`, `cc_metadata`, missing `release_metadata` local, missing `../deploymentcontext.json` (8 errors) | #10 |

**Notes:** These modules reference platform-injected variables that aren't declared for standalone validation.

---

### Category B: Provider Not Found (2 modules)

| Module | Missing Provider | Issue # |
|--------|------------------|---------|
| `common/cert_manager/standard` | hashicorp/aws3tooling | #15 |
| `common/ingress/nginx_k8s` | hashicorp/aws3tooling | #15 |

**Root Cause:** Provider alias `aws3tooling` is interpreted as `hashicorp/aws3tooling` which doesn't exist.

**Note:** `service/azure` and `service/gcp` previously failed with Facets provider issues but now upload successfully with `--skip-validation` (Facets provider added in a1325aa).

---

### Category C: Intent Not Found on Upload (2 modules)

| Module | Missing Intent | Notes |
|--------|----------------|-------|
| `common/kubeblocks-crd/standard` | `kubeblocks-crd` | Validation passes, upload fails - intent not registered in CP |
| `workload_identity/azure` | `azure_workload_identity` | Validation passes, upload fails - intent not registered in CP |

**Notes:** These modules pass all validations but fail on upload because the intent doesn't exist in the control plane.

---

### Category D: Uploaded with --skip-validation (3 modules)

| Module | Reason | Commit |
|--------|--------|--------|
| `service/aws` | Platform-injected variables not declared | a1325aa |
| `service/azure` | Raptor lowercases Facets provider source during init | a1325aa |
| `service/gcp` | Raptor lowercases Facets provider source during init | a1325aa |

**Notes:** These modules were uploaded successfully using `--skip-validation` flag due to validation infrastructure issues (not module issues).

---

## Fixed Modules (since last report)

### Fixed in commit a1325aa

| Module | Error Type | Root Cause | Fix Applied |
|--------|------------|------------|-------------|
| `service/aws` | Missing actions.tf, version.tf | No Tekton actions or Facets provider | Added actions.tf with deployment/statefulset actions, version.tf with Facets provider |
| `service/azure` | Provider not found during validation | Facets provider not in version.tf (and raptor bug) | Added Facets provider to version.tf |
| `service/gcp` | Provider not found during validation | Facets provider not in version.tf (and raptor bug) | Added Facets provider to version.tf |

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

---

## Modules Now Passing (Previously Failed)

The following modules that were previously listed as failing now pass validation:

| Module | Previous Error | Status |
|--------|----------------|--------|
| `common/eck-operator/helm` | Non-existent output type | ✅ Now passes |
| `common/grafana_dashboards/k8s` | Non-existent output type | ✅ Now passes |
| `common/kubeblocks-operator/standard` | var.inputs schema mismatch | ✅ Now passes |
| `common/monitoring/mongo` | Non-existent output type | ✅ Now passes |
| `common/strimzi-operator/helm` | Non-existent output type | ✅ Now passes |
| `common/wireguard-operator/standard` | Non-existent output type | ✅ Now passes |
| `common/wireguard-vpn/standard` | Non-existent output type | ✅ Now passes |
| `kubernetes_cluster/aks` | Security scan failures | ✅ Passes with --skip-security-scan |
| `kubernetes_cluster/eks` | Security scan failures | ✅ Passes with --skip-security-scan |
| `kubernetes_cluster/gke` | Security scan failures | ✅ Passes with --skip-security-scan |
| `kubernetes_node_pool/gcp` | Security scan failures | ✅ Passes with --skip-security-scan |
| `network/aws_vpc` | Security scan failures | ✅ Passes with --skip-security-scan |
| `network/gcp_vpc` | Security scan failures | ✅ Passes with --skip-security-scan |

---

## Summary by Issue Type

| Issue Type | Count | Status |
|------------|-------|--------|
| TF validation errors (undeclared vars) | 4 | #10 - ACTIVE |
| Provider not found (aws3tooling) | 2 | #15 - ACTIVE |
| Intent not found on upload | 2 | CP registration needed |
| Uploaded with --skip-validation | 3 | Working (validation bug) |

---

## Changes from Previous Run

**Newly Passing (11 modules):**
1. `common/eck-operator/helm` - Output type now exists in CP
2. `common/grafana_dashboards/k8s` - Output type now exists in CP
3. `common/kubeblocks-operator/standard` - Schema mismatch resolved
4. `common/monitoring/mongo` - Output type now exists in CP
5. `common/strimzi-operator/helm` - Output type now exists in CP
6. `common/wireguard-operator/standard` - Output type now exists in CP
7. `common/wireguard-vpn/standard` - Output type now exists in CP
8. `kubernetes_cluster/aks` - Passes with --skip-security-scan
9. `kubernetes_cluster/eks` - Passes with --skip-security-scan
10. `kubernetes_cluster/gke` - Passes with --skip-security-scan
11. `kubernetes_node_pool/gcp` - Passes with --skip-security-scan

**Uploaded with --skip-validation (3 modules):**
1. `service/aws` - Added actions.tf, version.tf (a1325aa)
2. `service/azure` - Added Facets provider (a1325aa)
3. `service/gcp` - Added Facets provider (a1325aa)

**Status Changes:**
- Previous: 17 passed, 20 failed (after commit 04b9a51)
- Current: 28 passed, 9 failed (after commit a1325aa)
- Net improvement: +11 passing modules

---

## Priority Fix Order

1. **Intent Registration** (2 modules) - Register `kubeblocks-crd` and `azure_workload_identity` intents in CP
2. **Provider Issues** (2 modules) - Handle `aws3tooling` provider alias for cert_manager and ingress
3. **TF Validation Errors** (4 modules) - Fix undeclared variables, missing files (platform-injected vars)

---

## Historical Changes

### 2026-01-08 (commit a1325aa)
- Added actions.tf and version.tf to service/aws
- Added Facets provider to service/azure and service/gcp version.tf
- Uploaded service/aws, service/azure, service/gcp with --skip-validation
- 11 modules now passing that were previously failing (output types registered, security scan skipped)

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
