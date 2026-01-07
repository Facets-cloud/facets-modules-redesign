# Facets Module Validation Issues & Fixes

This document catalogs all validation errors encountered during `raptor create iac-module` and `raptor import project-type` and their solutions.

---

## Issue Status Legend

| Status | Meaning |
|--------|---------|
| **ACTIVE** | Issue currently blocking module uploads |
| **FIXED** | Issue resolved - documented for reference |
| **BACKEND** | Requires backend/CP fix |
| **RAPTOR** | Requires raptor CLI fix |
| **WARNING** | Now a warning, not a blocker |

---

## 1. Sample.spec Validation Errors

### Error Pattern
```
sample.spec does not comply with module's spec schema: Validation error at '': doesn't validate with schema://sample.spec.json#
```

### Issue: Missing Required Fields in Sample
**Status:** ✅ FIXED

**Error:**
```
- : missing properties: 'cloud_account', 'region'
```

**Module:** `cloud_account/aws_provider`

**Problem:** The `sample` section had an empty `spec: {}` but the schema defined required properties.

**Incorrect:**
```yaml
sample:
  flavor: aws_provider
  kind: cloud_account
  disabled: false
  spec: {}
```

**Correct:**
```yaml
sample:
  flavor: aws_provider
  kind: cloud_account
  disabled: false
  spec:
    cloud_account: ""
    region: ""
```

**Rule:** Always include all required fields from the spec schema in the sample, even if with empty/default values.

---

### Issue: Missing Required Fields in Sample (azure_provider)
**Status:** ⚠️ ACTIVE

**Error:**
```
- : missing properties: 'cloud_account'
```

**Module:** `cloud_account/azure_provider`

**Problem:** The `sample` section is missing required `cloud_account` property.

**Rule:** Always include all required fields from the spec schema in the sample.

---

### Issue: Invalid Enum Value in Sample
**Status:** ✅ FIXED

**Error:**
```
- /cluster/cluster_addons/eks-cluster-addons2/name: value must be one of "aws-efs-csi-driver", "aws-fsx-csi-driver", ...
```

**Module:** `kubernetes_cluster/eks`

**Problem:** Sample used `metrics-server` which is not in the allowed enum values.

**Incorrect:**
```yaml
sample:
  spec:
    cluster:
      cluster_addons:
        eks-cluster-addons2:
          name: metrics-server  # Not in enum!
          enabled: true
```

**Correct:**
```yaml
sample:
  spec:
    cluster:
      cluster_addons:
        eks-cluster-addons2:
          name: eks-node-agent  # Valid enum value
          enabled: true
```

**Rule:** Sample values must match enum constraints defined in the spec schema.

---

### Issue: Null Value Where Object Expected
**Status:** ✅ FIXED

**Error:**
```
- /values: expected object, but got null
```

**Module:** `helm/k8s_standard`

**Problem:** Schema defines `values` as `type: object` with `default: {}`, but sample had `null`.

**Incorrect:**
```yaml
sample:
  spec:
    helm:
      chart: datadog
      ...
    values: null
```

**Correct:**
```yaml
sample:
  spec:
    helm:
      chart: datadog
      ...
    values: {}
```

**Rule:** When schema specifies `type: object`, use `{}` not `null` in sample.

---

### Issue: Array Where Object Expected
**Status:** ✅ FIXED

**Error:**
```
- /tolerations: expected object, but got array
```

**Module:** `prometheus/k8s_standard`

**Problem:** Schema defines `tolerations` as `type: object` (using patternProperties), but sample used an array.

**Incorrect:**
```yaml
sample:
  spec:
    tolerations: []
```

**Correct:**
```yaml
sample:
  spec:
    tolerations: {}
```

**Rule:** Check the schema type carefully. Objects with `patternProperties` are still objects (`{}`), not arrays (`[]`).

---

## 2. Invalid Regex Patterns ✅ FIXED

### Error Pattern
```
'/properties/.../pattern' does not validate with http://json-schema.org/draft-07/schema#/.../pattern/format: '...' is not valid 'regex'
```

### Issue: Lookahead/Lookbehind Not Supported
**Status:** ✅ FIXED

**Error:**
```
'^(?!0$)([1-9][0-9]{0,3}|...)$' is not valid 'regex'
```

**Modules:** `service/aws`, `service/azure`, `service/gcp`, `ingress/nginx_k8s`

**Problem:** JSON Schema regex does not support:
- Lookahead: `(?=...)`, `(?!...)`
- Lookbehind: `(?<=...)`, `(?<!...)`

**Incorrect (service port pattern):**
```yaml
pattern: ^(?!0$)([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$
```

**Correct:**
```yaml
pattern: ^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$
```
*Note: The `(?!0$)` was redundant since `[1-9]` already excludes leading zero.*

**Commit:** `ed8034a` - fix: remove invalid regex lookahead and required_providers blocks

---

**Incorrect (ingress/nginx_k8s domain pattern):**
```yaml
pattern: ^(?=.{1,253}$)(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.[A-Za-z0-9-]{1,63})*\.[A-Za-z]{2,6}$
```

**Correct:**
```yaml
pattern: ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*\.[A-Za-z]{2,6}$
```
*Rewrites "cannot start/end with hyphen" using character classes instead of lookahead/lookbehind.*

---

**Incorrect (ingress/nginx_k8s domain_prefix pattern):**
```yaml
pattern: ^(?!-)[a-z0-9-]{1,36}(?<!-)$
```

**Correct:**
```yaml
pattern: ^[a-z0-9]([a-z0-9-]{0,34}[a-z0-9])?$|^[a-z0-9]$
```
*Handles both single character and multi-character cases without lookahead/lookbehind.*

**Rule:** Avoid lookahead (`(?=...)`, `(?!...)`) and lookbehind (`(?<=...)`, `(?<!...)`) in JSON Schema patterns. Rewrite using explicit character classes.

---

## 3. Duplicate Enum Values ✅ FIXED

### Issue: Duplicate Value in Enum Array
**Status:** ✅ FIXED

**Module:** `ingress/nginx_k8s`

**Problem:** The `header_name` enum had `Cache-Control` listed twice.

**Incorrect:**
```yaml
enum:
  - X-Frame-Options
  - Content-Security-Policy
  - Cache-Control
  - Cache-Control  # Duplicate!
  - Vary
```

**Correct:**
```yaml
enum:
  - X-Frame-Options
  - Content-Security-Policy
  - Cache-Control
  - Vary
```

**Rule:** Enum values must be unique. Review enums for accidental duplicates.

---

## 4. Remote Module References ✅ FIXED

### Error Pattern
```
remote module validation failed: remote module references found:
  - file.tf:3 - "github.com/Facets-cloud/facets-utility-modules//name"
Modules should only use local relative paths (e.g., ./modules/submodule)
```

### Issue: External GitHub Module Source
**Status:** ✅ FIXED (validation changed to opt-in with `--block-remote-modules` flag)

**Module:** `artifactories/standard`

**Problem:** Module references external GitHub repository instead of local paths.

**Incorrect:**
```hcl
module "name" {
  source = "github.com/Facets-cloud/facets-utility-modules//name"
  ...
}
```

**Correct Options:**
1. Inline the module code directly
2. Use a local submodule: `source = "./modules/name"`
3. Copy the utility module into the module directory

**Rule:** Facets modules must be self-contained. Use local relative paths for submodules, not external repositories.

**Note:** As of raptor PR #41, remote module validation is now opt-in with `--block-remote-modules` flag.

---

## 5. Required Providers Block in Module Files ⚠️ WARNING

### Error Pattern
```
provider validation failed: required_providers block found in versions.tf at line X. Modules should not define required_providers
```

### Issue: Module Defines required_providers
**Status:** ⚠️ WARNING (now shows warning instead of error)

**Module:** `k8s_callback/k8s_standard`

**Problem:** Modules should not define `required_providers` as providers are injected by the Facets platform.

**Incorrect:**
```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}
```

**Correct:**
```hcl
terraform {
  required_version = ">= 1.0"
}
```

**Rule:** Do not include `required_providers` blocks in Facets modules. Provider configuration is handled by the platform based on inputs with `providers:` specified.

**Note:** Raptor now shows a warning instead of failing validation for required_providers blocks.

---

## 6. Variable Inputs Type Definition ✅ FIXED

### Error Pattern
```
failed to parse var.inputs: inputs variable must be an object type
```

### Issue: Using `type = any` or `type = map(any)` for inputs
**Status:** ✅ FIXED

**Modules:** `kubernetes_node_pool/aws`, `network/aws_vpc`, `cert_manager/standard`, `config_map/k8s_standard`, `k8s_resource/k8s_standard`, `kubernetes_secret/k8s_standard`, `vpa/standard`, `ingress/nginx_k8s`

**Recent Fix:** `ingress/nginx_k8s` - Commit `8c1204e` - Changed `var.inputs` from `type = any` to explicit object type

**Problem:** The `inputs` variable must have a proper object type definition, not `any` or `map(any)`.

**Incorrect:**
```hcl
variable "inputs" {
  type = any
}
```

**Also Incorrect:**
```hcl
variable "inputs" {
  type = map(any)
}
```

**Correct:**
```hcl
variable "inputs" {
  type = object({
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider    = optional(string)
        cluster_id        = optional(string)
        cluster_name      = optional(string)
        cluster_location  = optional(string)
        cluster_endpoint  = optional(string)
      }))
      interfaces = optional(object({
        kubernetes = optional(object({
          cluster_ca_certificate = optional(string)
          host                   = optional(string)
        }))
      }))
    })
  })
}
```

**How to Build the Type:**
1. Check the module's `facets.yaml` for the `inputs:` section
2. Each input key becomes a top-level key in the object type
3. Look up the input's `type:` value (e.g., `@facets/kubernetes-details`)
4. Find the corresponding schema in `outputs/{type-name}/outputs.yaml`
5. Convert the YAML schema to Terraform object type, using `optional()` for flexibility

**Rule:** Always define `var.inputs` with an explicit object type structure that matches the schema of input types declared in `facets.yaml`.

---

## 7. Output Type Schema Issues - ACTIVE (BACKEND)

### Error Pattern
```
var.inputs validation failed:
  - var.inputs.X: failed to parse schema: property 'interfaces': schema missing 'type' field
  - var.inputs.X: failed to parse schema: property 'attributes': property 'Y': schema missing 'type' field
```

### Issue: Missing 'type' Field in Output Schema
**Status:** ⚠️ ACTIVE - Requires backend fix

**Modules:** `kubernetes_cluster/eks`, `network/aws_vpc`, `service/aws`

**Problem:** The output type schema stored in CP is missing the `type` field for nested properties. This appears to be a backend issue where the CP strips or doesn't store nested `type: object` fields properly.

**Error Example:**
```
var.inputs.cloud_account: failed to parse schema: property 'attributes': schema missing 'type' field
```

**Affected Output Type:** `@facets/aws_cloud_account`

**Expected Schema (outputs/aws_cloud_account/outputs.yaml):**
```yaml
properties:
  attributes:
    type: object
    properties:
      aws_region:
        type: string
  interfaces:
    type: object  # Required!
    properties:
      ...
```

**Rule:** Every object in the output schema must have an explicit `type: object` field.

**Workaround:** None currently - requires backend fix to properly store nested schema types.

---

### Issue: Union Types Not Supported
**Status:** ✅ FIXED

**Error:**
```
property 'vpc_endpoint_dynamodb_id': schema missing 'type' field
```

**Problem:** Using YAML array syntax for union types like `type: ["string", "null"]` is not supported.

**Incorrect (outputs/aws-vpc-details/outputs.yaml):**
```yaml
vpc_endpoint_dynamodb_id:
  type:
    - string
    - "null"
```

**Correct:**
```yaml
vpc_endpoint_dynamodb_id:
  type: string  # Use simple type, handle null in Terraform with optional()
```

**Rule:** Use simple types in output schemas. Handle nullability in Terraform using `optional()` wrapper.

---

## 8. patternProperties Required Field Indentation ✅ FIXED

### Error Pattern
```
sample.spec does not comply with module's spec schema: Validation error at '': doesn't validate with schema://sample.spec.json#
Details:
  - /rules: missing properties: 'service_name', 'path', 'port'
```

### Issue: `required` Array at Wrong Indentation Level
**Status:** ✅ FIXED

**Module:** `ingress/nginx_k8s`

**Problem:** The `required` array was placed at the same indentation level as `patternProperties` (sibling), instead of inside the pattern definition. This makes JSON Schema interpret it as "the parent object must have these properties directly" rather than "matched pattern objects must have these properties".

**Incorrect:**
```yaml
rules:
  type: object
  patternProperties:
    ^[a-zA-Z0-9_.-]*$:
      type: object
      properties:
        service_name: ...
        path: ...
        port: ...
      # required should be here (10 spaces)
  required:        # Wrong! At 6 spaces - sibling of patternProperties
  - service_name
  - path
  - port
```

**Correct:**
```yaml
rules:
  type: object
  patternProperties:
    ^[a-zA-Z0-9_.-]*$:
      type: object
      properties:
        service_name: ...
        path: ...
        port: ...
      required:    # Correct! At 10 spaces - inside pattern definition
      - service_name
      - path
      - port
```

**Why This Matters:**
- With wrong indentation: `rules: {}` (empty object) fails validation because `rules` itself must have `service_name`, `path`, `port`
- With correct indentation: `rules: {}` passes validation because there are no matched patterns to validate against

**Rule:** When using `patternProperties`, place `required` inside the pattern definition (same indentation as `properties`), not as a sibling of `patternProperties`.

---

## 9. var.instance.spec Validation Errors

### Error Pattern
```
var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.X: expected object, got map
```

### Issue: Terraform Type Mismatch
**Status:** ✅ FIXED

**Module:** `vpa/standard`

**Problem:** The Terraform variable type definition uses `map(any)` but the facets.yaml schema expects a specific object structure.

**Incorrect:**
```hcl
variable "instance" {
  type = object({
    spec = object({
      recommender = object({
        configuration = optional(map(any))  # Too loose!
      })
    })
  })
}
```

**Correct:**
```hcl
variable "instance" {
  type = object({
    spec = object({
      recommender = object({
        configuration = optional(object({}))  # Match schema expectation
      })
    })
  })
}
```

**Rule:** Match Terraform variable types exactly to facets.yaml schema. Use `object({})` for empty objects, not `map(any)`.

---

### Issue: Missing Required Property in var.instance.spec
**Status:** ⚠️ ACTIVE

**Error:**
```
var.instance.spec does not match schema defined in facets.yaml: at spec: missing required property 'name'
```

**Modules:** `workload_identity/azure` (missing `name`), `workload_identity/gcp` (missing `identity_name`)

**Problem:** The Terraform variable type definition doesn't include required properties from the facets.yaml schema.

**Rule:** Ensure var.instance.spec type definition includes all required properties from facets.yaml schema.

---

## 10. Terraform Validation Errors - ACTIVE

### Error Pattern
```
terraform validate failed: terraform validation failed with X error(s)
Reference to undeclared input variable: An input variable with the name "X" has not been declared.
```

### Issue: Undeclared Variables
**Status:** ⚠️ ACTIVE - Requires module code fix

**Modules:**
- `k8s_callback/k8s_standard` - missing `cluster`, `cc_metadata`
- `prometheus/k8s_standard` - missing `cc_metadata`

**Problem:** Module references variables that are not declared in variables.tf.

**Error:**
```
An input variable with the name "cluster" has not been declared.
An input variable with the name "cc_metadata" has not been declared.
```

**Solution:** Either:
1. Declare the missing variables in variables.tf
2. Remove references to these variables from the Terraform code

**Rule:** All referenced variables must be declared in variables.tf.

---

### Issue: Missing File Reference
**Status:** ⚠️ ACTIVE - Requires module code fix

**Error:**
```
Invalid function argument: Invalid value for "path" parameter: no file exists at "../deploymentcontext.json"
```

**Modules:** `service/aws`, `artifactories/standard`

**Problem:** Module uses `file()` function to reference a file that doesn't exist at validation time.

**Solution:** Either:
1. Use a different approach to get the data (e.g., input variable)
2. Use `fileexists()` with conditional logic
3. Provide a stub file for validation

**Rule:** Don't reference files that only exist at deployment time in Terraform code.

---

## 11. Nested Duplicate Enum Values ✅ FIXED

### Error Pattern
```
'/properties/X/patternProperties/.../properties/Y/enum' does not validate with .../uniqueItems: items at index N and M are equal
```

### Issue: Duplicate Enum in Nested Structure
**Status:** ✅ FIXED

**Module:** `ingress/nginx_k8s`

**Problem:** The duplicate enum exists not only at the top level but also in nested `patternProperties` structures like `rules.*.more_set_headers.*.header_name`.

**Location:** `spec.rules.{pattern}.more_set_headers.{pattern}.header_name`

**Rule:** Check ALL occurrences of enum arrays in the schema, including those in nested patternProperties.

---

## 12. Nested Invalid Regex Patterns ✅ FIXED

### Error Pattern
```
'/properties/sidecars/patternProperties/.../properties/port/pattern' does not validate with .../pattern/format: '...' is not valid 'regex'
```

### Issue: Invalid Regex in Nested Structure
**Status:** ✅ FIXED

**Module:** `service/aws`, `service/azure`, `service/gcp`

**Problem:** The invalid regex pattern exists not only in the main `ports` section but also in nested structures like `sidecars.*.runtime.ports.*.port`.

**Rule:** When fixing regex patterns, search for ALL occurrences of the pattern in the file, including nested structures.

---

## 13. Required Providers in .terraform/modules/ ⚠️ WARNING

### Error Pattern
```
provider validation failed: required_providers block found in .terraform/modules/X/application/versions.tf at line 2. Modules should not define required_providers
```

### Issue: Raptor Scans Downloaded Remote Modules
**Status:** ⚠️ WARNING (now shows warning instead of error)

**Modules:** `kubernetes_node_pool/aws`, `artifactories/standard`, `cert_manager/standard`, `ingress/nginx_k8s`, `prometheus/k8s_standard`

**Problem:** When a module uses remote module sources (e.g., `github.com/Facets-cloud/facets-utility-modules//...`), Terraform downloads them to `.terraform/modules/`. Raptor then scans this directory and finds `required_providers` blocks in the downloaded modules.

**Error Examples:**
```
required_providers block found in .terraform/modules/node_class/application/versions.tf
required_providers block found in .terraform/modules/name/application/versions.tf
required_providers block found in .terraform/modules/cluster-issuer/application/versions.tf
required_providers block found in .terraform/modules/custom_error_pages_configmap/application/versions.tf
required_providers block found in .terraform/modules/alertmanager-pvc/application/versions.tf
```

**Root Cause:** Raptor's provider validation recursively scans all `.tf` files including those in `.terraform/modules/` which contains downloaded external modules that legitimately have their own `required_providers` blocks.

**Fix:** Raptor now shows a warning instead of failing validation. The warning can be ignored for `.terraform/modules/` paths.

---

## 14. Output Type Corruption During Import ✅ FIXED

### Error Pattern
```
failed to fetch schema for input 'X' (type '@facets/Y'): unexpected properties type: <nil>
```

### Issue: Output Types Corrupted to `properties: null`
**Status:** ✅ FIXED (Backend fix deployed)

**Modules:** Previously affected `helm/k8s_standard`, `ingress/nginx_k8s`, `k8s_callback/k8s_standard`, `k8s_resource/k8s_standard`, `kubernetes_secret/k8s_standard`, `prometheus/k8s_standard`, `vpa/standard`

**Problem:** During `raptor import project-type`, output types that were created with proper properties would get corrupted to `properties: null`. This was traced to the `--auto-create` flag behavior during module upload.

**Root Cause:** The backend was not properly preserving output type properties when modules were uploaded with auto-create enabled.

**Fix:** Backend fix deployed - output types are no longer corrupted during import.

---

## 15. Provider Not Found - ACTIVE

### Error Pattern
```
terraform init failed: exit status 1
Error: Failed to query available provider packages
Could not retrieve the list of available versions for provider hashicorp/X
```

### Issue: Facets Provider Not Found
**Status:** ⚠️ ACTIVE - Requires raptor/platform fix

**Error:**
```
Could not retrieve the list of available versions for provider hashicorp/facets
```

**Modules:** `service/azure`, `service/gcp`

**Problem:** Module uses `facets_tekton_action_kubernetes` resources which require the `Facets-cloud/facets` provider. Without `required_providers` block, Terraform looks for `hashicorp/facets` which doesn't exist.

**Root Cause:**
- Raptor validation doesn't allow `required_providers` blocks
- But without them, Terraform defaults to `hashicorp/` namespace for unknown providers

**Workaround:** Raptor/platform needs to auto-inject the facets provider source during validation.

---

### Issue: aws3tooling Provider Not Found
**Status:** ⚠️ ACTIVE - Requires module fix

**Error:**
```
Could not retrieve the list of available versions for provider hashicorp/aws3tooling
```

**Modules:** `cert_manager/standard`, `ingress/nginx_k8s`

**Problem:** Module uses provider alias `aws3tooling` which Terraform interprets as `hashicorp/aws3tooling`.

**Root Cause:** Provider aliases for platform-injected providers need to be handled differently.

---

## 16. Security Scan Failures - ACTIVE

### Error Pattern
```
security scan failed: found X HIGH/CRITICAL security issue(s)
```

### Issue: Trivy Security Scan Failures
**Status:** ⚠️ ACTIVE - Requires security review

**Modules:**
- `kubernetes_cluster/aks` - 9 HIGH/CRITICAL issues
- `kubernetes_cluster/eks` - 13 HIGH/CRITICAL issues
- `kubernetes_cluster/gke` - 1 HIGH/CRITICAL issue
- `kubernetes_node_pool/gcp` - 1 HIGH/CRITICAL issue
- `network/aws_vpc` - 1 HIGH/CRITICAL issue
- `network/gcp_vpc` - 1 HIGH/CRITICAL issue

**Problem:** Trivy security scanner finds HIGH or CRITICAL severity issues in the Terraform code.

**Solution:** Review each issue and either:
1. Fix the security concern
2. Document and accept the risk
3. Use `--skip-security-scan` flag (not recommended for production)

---

## 17. Unreadable Module Directory - ACTIVE

### Error Pattern
```
terraform init failed: exit status 1
Error: Unreadable module directory
Unable to evaluate directory symlink: lstat /Users/X: no such file or directory
```

### Issue: Broken Symlink in Module
**Status:** ⚠️ ACTIVE - Requires module fix

**Module:** `kubernetes_node_pool/gcp_node_fleet`

**Problem:** Module contains a symlink that points to a non-existent path.

**Solution:** Fix or remove the broken symlink in the module.

---

## Summary Table

| Issue # | Error Type | Status | Modules Affected |
|---------|------------|--------|------------------|
| 1 | Sample.spec validation | ⚠️ PARTIAL | ~~cloud_account/aws_provider~~, cloud_account/azure_provider |
| 2 | Invalid regex patterns | ✅ FIXED | ~~service/aws~~, ~~service/azure~~, ~~service/gcp~~, ~~ingress/nginx_k8s~~ |
| 3 | Duplicate enum values | ✅ FIXED | ~~ingress/nginx_k8s~~ |
| 4 | Remote module references | ✅ FIXED | (validation now opt-in) |
| 5 | required_providers in module | ⚠️ WARNING | (now shows warning, not error) |
| 6 | var.inputs type=any | ✅ FIXED | ~~multiple modules~~ |
| 7 | Output schema missing type | ⚠️ BACKEND | kubernetes_cluster/eks, network/aws_vpc, service/aws |
| 8 | patternProperties indentation | ✅ FIXED | ~~ingress/nginx_k8s~~ |
| 9 | var.instance.spec mismatch | ⚠️ PARTIAL | ~~vpa/standard~~, workload_identity/azure, workload_identity/gcp |
| 10 | Undeclared variables | ⚠️ ACTIVE | k8s_callback/k8s_standard, prometheus/k8s_standard, service/aws |
| 11 | Nested duplicate enum | ✅ FIXED | ~~ingress/nginx_k8s~~ |
| 12 | Nested invalid regex | ✅ FIXED | ~~service/aws~~, ~~service/azure~~, ~~service/gcp~~ |
| 13 | .terraform/modules scanning | ⚠️ WARNING | (now shows warning, not error) |
| 14 | Output type corruption | ✅ FIXED | (backend fix deployed) |
| 15 | Provider not found | ⚠️ ACTIVE | service/azure, service/gcp, cert_manager, ingress |
| 16 | Security scan failures | ⚠️ ACTIVE | aks, eks, gke, gcp node_pool, aws_vpc, gcp_vpc |
| 17 | Unreadable module directory | ⚠️ ACTIVE | kubernetes_node_pool/gcp_node_fleet |

---

## Current Status (as of 2026-01-07, updated after commit 38e4e10)

### Modules Successfully Validated (19)
- `cloud_account/aws_provider` ✅
- `cloud_account/gcp_provider` ✅
- `common/config_map/k8s_standard` ✅
- `common/eck-operator/helm` ✅
- `common/grafana_dashboards/k8s` ✅
- `common/helm/k8s_standard` ✅
- `common/k8s_resource/k8s_standard` ✅
- `common/kubeblocks-crd/standard` ✅
- `common/kubeblocks-operator/standard` ✅
- `common/kubernetes_secret/k8s_standard` ✅
- `common/monitoring/mongo` ✅
- `common/strimzi-operator/helm` ✅
- `common/vpa/standard` ✅
- `common/wireguard-operator/standard` ✅
- `common/wireguard-vpn/standard` ✅
- `kubernetes_node_pool/aws` ✅
- `kubernetes_node_pool/azure` ✅
- `network/azure_network` ✅
- `pubsub/gcp` ✅

### Modules Failed Validation (18)

| Module | Error Type | Issue # |
|--------|------------|---------|
| `cloud_account/azure_provider` | Sample.spec: missing `cloud_account` | #1 |
| `common/artifactories/standard` | TF validate: 1 error | #10 |
| `common/cert_manager/standard` | Provider not found: aws3tooling | #15 |
| `common/ingress/nginx_k8s` | Provider not found: aws3tooling | #15 |
| `common/k8s_callback/k8s_standard` | TF validate: 4 errors (undeclared variables) | #10 |
| `common/prometheus/k8s_standard` | TF validate: 4 errors (undeclared variables) | #10 |
| `kubernetes_cluster/aks` | Security scan: 9 issues | #16 |
| `kubernetes_cluster/eks` | Security scan: 13 issues | #16 |
| `kubernetes_cluster/gke` | Security scan: 1 issue | #16 |
| `kubernetes_node_pool/gcp` | Security scan: 1 issue | #16 |
| `kubernetes_node_pool/gcp_node_fleet` | Unreadable module directory | #17 |
| `network/aws_vpc` | Security scan: 1 issue | #16 |
| `network/gcp_vpc` | Security scan: 1 issue | #16 |
| `service/aws` | TF validate: 9 errors | #10 |
| `service/azure` | Provider not found: facets | #15 |
| `service/gcp` | Provider not found: facets | #15 |
| `workload_identity/azure` | var.instance.spec: missing `identity_name` | #9 |
| `workload_identity/gcp` | var.instance.spec: missing `name` | #9 |

---

## Quick Reference: Validation Checklist

Before publishing a module, verify:

- [ ] Sample.spec includes all required fields with valid values
- [ ] Sample values match enum constraints
- [ ] Use `{}` for object types, `[]` for array types (never `null`)
- [ ] Regex patterns avoid lookahead/lookbehind (check ALL occurrences including nested structures)
- [ ] Enum arrays have no duplicates (check ALL occurrences including nested patternProperties)
- [ ] `required` arrays in patternProperties are correctly indented (inside pattern, not sibling)
- [ ] No external module sources (use local paths only) - or use `--block-remote-modules` flag
- [ ] No `required_providers` block in terraform files (now warning, but best to remove)
- [ ] `var.inputs` has explicit object type (not `any` or `map(any)`)
- [ ] Output schemas have `type: object` for all object properties
- [ ] Output schemas use simple types (no union types like `["string", "null"]`)
- [ ] `var.instance.spec` types match facets.yaml schema exactly
- [ ] All referenced variables are declared in variables.tf
- [ ] No broken symlinks or missing file references
- [ ] Security scan passes (no HIGH/CRITICAL issues)
