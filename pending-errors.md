# Pending Module Validation Errors

Generated: 2026-01-06

## Summary

| Status | Count |
|--------|-------|
| ✓ Uploaded | 2 |
| ❌ Failed | 11 |
| ✅ Fixed | 2 |

---

## Successful Modules (2)

1. `cloud_account/aws_provider` - ✓ Published
2. `config_map/k8s_standard` - ✓ Published

---

## Fixed Modules (1)

### ✅ ingress/nginx_k8s

**Error Type:** Sample Spec Validation - patternProperties required indentation

**Original Error:**
```
sample.spec does not comply with module's spec schema: Validation error at '': doesn't validate with schema://sample.spec.json#
Details:
  - /rules: missing properties: 'service_name', 'path', 'port'
```

**Root Cause:** The `required: [service_name, path, port]` was at the wrong indentation level (6 spaces, sibling of `patternProperties`) instead of inside the pattern definition (10 spaces). This made JSON Schema interpret it as "the `rules` object itself must have these properties" rather than "matched pattern objects must have these properties".

**Fix Applied:** Moved `required` block from 6-space indentation to 10-space indentation in `modules/common/ingress/nginx_k8s/1.0/facets.yaml`

**Commit:** `c3dfccb` - fix: correct required field indentation in ingress/nginx_k8s schema

---

### ✅ kubernetes_node_pool/aws

**Error Type:** Terraform Validation - Unsupported Attribute

**Original Error:**
```
terraform validation failed with 1 error(s)
Unsupported attribute: This object does not have an attribute named "database_subnet_ids".
```

**Root Cause:** The `subnet_ids_map` in `locals.tf` referenced `database_subnet_ids` which doesn't exist in the network output schema. Node pools only need private and public subnets.

**Fix Applied:** Removed `database` entry from `subnet_ids_map` in `modules/kubernetes_node_pool/aws/1.0/locals.tf`

**Commit:** `82a485f` - fix: remove database_subnet_ids from kubernetes_node_pool/aws

---

## Failed Modules (11)

### 1. kubernetes_cluster/eks

**Error Type:** Output Schema Missing Type Field

**Error:**
```
var.inputs validation failed:
  - var.inputs.cloud_account: failed to parse schema: property 'attributes': schema missing 'type' field
```

**Root Cause:** The `@facets/aws_cloud_account` output type schema is missing `type: object` for the `attributes` property.

**File to Fix:** `outputs/aws_cloud_account/outputs.yaml`

---

### 2. network/aws_vpc

**Error Type:** Output Schema Missing Type Field

**Error:**
```
var.inputs validation failed:
  - var.inputs.cloud_account: failed to parse schema: property 'attributes': schema missing 'type' field
```

**Root Cause:** Same as #1 - The `@facets/aws_cloud_account` output type schema issue.

**File to Fix:** `outputs/aws_cloud_account/outputs.yaml`

---

### 3. service/aws

**Error Type:** Output Schema Missing Type Field

**Error:**
```
var.inputs validation failed:
  - var.inputs.cloud_account: failed to parse schema: property 'attributes': schema missing 'type' field
```

**Root Cause:** Same as #1 - The `@facets/aws_cloud_account` output type schema issue.

**File to Fix:** `outputs/aws_cloud_account/outputs.yaml`

---

### 4. artifactories/standard

**Error Type:** Terraform Validation - Invalid File Reference

**Error:**
```
terraform validation failed with 1 error(s)
Invalid function argument: Invalid value for "path" parameter: no file exists at "../deploymentcontext.json";
this function works only with files that are distributed as part of the configuration source code
```

**Root Cause:** Module references `../deploymentcontext.json` which doesn't exist during validation.

**File to Fix:** `modules/common/artifactories/standard/1.0/*.tf`

---

### 5. cert_manager/standard

**Error Type:** Terraform Init - Invalid Provider

**Error:**
```
terraform init failed:
Could not retrieve the list of available versions for provider hashicorp/aws3tooling:
provider registry registry.terraform.io does not have a provider named registry.terraform.io/hashicorp/aws3tooling
```

**Root Cause:** Invalid provider reference `hashicorp/aws3tooling` (typo or non-existent provider).

**File to Fix:** `modules/common/cert_manager/standard/1.0/*.tf` - search for `aws3tooling` reference

---

### 6. helm/k8s_standard

**Error Type:** Output Schema - Unexpected Properties Type

**Error:**
```
failed to fetch schema for input 'kubernetes_details' (type '@facets/kubernetes-details'): unexpected properties type: <nil>
```

**Root Cause:** The `@facets/kubernetes-details` output type schema has malformed properties structure.

**File to Fix:** `outputs/kubernetes-details/outputs.yaml`

---

### 7. k8s_callback/k8s_standard

**Error Type:** Output Schema - Unexpected Properties Type

**Error:**
```
failed to fetch schema for input 'kubernetes_details' (type '@facets/kubernetes-details'): unexpected properties type: <nil>
```

**Root Cause:** Same as #7 - The `@facets/kubernetes-details` output type schema issue.

**File to Fix:** `outputs/kubernetes-details/outputs.yaml`

---

### 8. k8s_resource/k8s_standard

**Error Type:** Output Schema - Unexpected Properties Type

**Error:**
```
failed to fetch schema for input 'kubernetes_details' (type '@facets/kubernetes-details'): unexpected properties type: <nil>
```

**Root Cause:** Same as #7 - The `@facets/kubernetes-details` output type schema issue.

**File to Fix:** `outputs/kubernetes-details/outputs.yaml`

---

### 9. kubernetes_secret/k8s_standard

**Error Type:** Output Schema - Unexpected Properties Type

**Error:**
```
failed to fetch schema for input 'kubernetes_details' (type '@facets/kubernetes-details'): unexpected properties type: <nil>
```

**Root Cause:** Same as #7 - The `@facets/kubernetes-details` output type schema issue.

**File to Fix:** `outputs/kubernetes-details/outputs.yaml`

---

### 10. prometheus/k8s_standard

**Error Type:** Output Schema - Unexpected Properties Type

**Error:**
```
failed to fetch schema for input 'kubernetes_details' (type '@facets/kubernetes-details'): unexpected properties type: <nil>
```

**Root Cause:** Same as #7 - The `@facets/kubernetes-details` output type schema issue.

**File to Fix:** `outputs/kubernetes-details/outputs.yaml`

---

### 11. vpa/standard

**Error Type:** Output Schema - Unexpected Properties Type

**Error:**
```
failed to fetch schema for input 'kubernetes_details' (type '@facets/kubernetes-details'): unexpected properties type: <nil>
```

**Root Cause:** Same as #7 - The `@facets/kubernetes-details` output type schema issue.

**File to Fix:** `outputs/kubernetes-details/outputs.yaml`

---

## Errors Grouped by Root Cause

### Group A: `@facets/aws_cloud_account` - Missing `type: object` (3 modules)
- kubernetes_cluster/eks
- network/aws_vpc
- service/aws

**Fix:** Add `type: object` to `attributes` property in `outputs/aws_cloud_account/outputs.yaml`

---

### Group B: `@facets/kubernetes-details` - Malformed Properties (7 modules)
- helm/k8s_standard
- k8s_callback/k8s_standard
- k8s_resource/k8s_standard
- kubernetes_secret/k8s_standard
- prometheus/k8s_standard
- vpa/standard

**Fix:** Fix the properties structure in `outputs/kubernetes-details/outputs.yaml`

---

### Group C: Terraform Validation Errors (2 modules)
- ~~kubernetes_node_pool/aws - `database_subnet_ids` attribute doesn't exist~~ → Fixed in commit `82a485f`
- artifactories/standard - File reference `../deploymentcontext.json` doesn't exist

---

### Group D: Provider Issues (1 module)
- cert_manager/standard - Invalid provider `hashicorp/aws3tooling`

---

### ~~Group E: Sample Spec Validation (1 module)~~ ✅ FIXED
- ~~ingress/nginx_k8s - Missing required properties in `rules`~~ → Fixed in commit `c3dfccb`

---

## Priority Fix Order

1. **`outputs/kubernetes-details/outputs.yaml`** - Fixes 7 modules (CP backend issue #38)
2. **`outputs/aws_cloud_account/outputs.yaml`** - Fixes 3 modules (CP backend issue #42)
3. ~~**`modules/common/ingress/nginx_k8s/1.0/facets.yaml`** - Fixes 1 module~~ ✅ FIXED
4. ~~**`modules/kubernetes_node_pool/aws/1.0/*.tf`** - Fixes 1 module~~ ✅ FIXED
5. **`modules/common/artifactories/standard/1.0/*.tf`** - Fixes 1 module
6. **`modules/common/cert_manager/standard/1.0/*.tf`** - Fixes 1 module
