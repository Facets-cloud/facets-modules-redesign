# Facets Module Validation Issues & Fixes

This document catalogs all validation errors encountered during `raptor import project-type` and their solutions.

---

## 1. Sample.spec Validation Errors

### Error Pattern
```
sample.spec does not comply with module's spec schema: Validation error at '': doesn't validate with schema://sample.spec.json#
```

### Issue: Missing Required Fields in Sample
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

### Issue: Invalid Enum Value in Sample
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

## 2. Invalid Regex Patterns

### Error Pattern
```
'/properties/.../pattern' does not validate with http://json-schema.org/draft-07/schema#/.../pattern/format: '...' is not valid 'regex'
```

### Issue: Lookahead/Lookbehind Not Supported
**Error:**
```
'^(?!0$)([1-9][0-9]{0,3}|...)$' is not valid 'regex'
```

**Modules:** `service/aws`, `ingress/nginx_k8s`

**Problem:** JSON Schema regex does not support:
- Lookahead: `(?=...)`, `(?!...)`
- Lookbehind: `(?<=...)`, `(?<!...)`

**Incorrect (service/aws port pattern):**
```yaml
pattern: ^(?!0$)([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$
```

**Correct:**
```yaml
pattern: ^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$
```
*Note: The `(?!0$)` was redundant since `[1-9]` already excludes leading zero.*

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

## 3. Duplicate Enum Values

### Issue: Duplicate Value in Enum Array
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

## 4. Remote Module References

### Error Pattern
```
remote module validation failed: remote module references found:
  - file.tf:3 - "github.com/Facets-cloud/facets-utility-modules//name"
Modules should only use local relative paths (e.g., ./modules/submodule)
```

### Issue: External GitHub Module Source
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

---

## 5. Required Providers Block

### Error Pattern
```
provider validation failed: required_providers block found in versions.tf at line X. Modules should not define required_providers
```

### Issue: Module Defines required_providers
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

---

## 6. Variable Inputs Type Definition

### Error Pattern
```
failed to parse var.inputs: inputs variable must be an object type
```

### Issue: Using `type = any` or `type = map(any)` for inputs
**Modules:** `kubernetes_node_pool/aws`, `network/aws_vpc`, `cert_manager/standard`, `config_map/k8s_standard`, `k8s_resource/k8s_standard`, `kubernetes_secret/k8s_standard`, `vpa/standard`

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

## 7. Output Type Schema Issues

### Error Pattern
```
var.inputs validation failed:
  - var.inputs.X: failed to parse schema: property 'interfaces': schema missing 'type' field
  - var.inputs.X: failed to parse schema: property 'attributes': property 'Y': schema missing 'type' field
```

### Issue: Missing 'type' Field in Output Schema
**Modules:** `kubernetes_cluster/eks`, `kubernetes_node_pool/aws`, `network/aws_vpc`

**Problem:** The output type schema in `outputs/{type}/outputs.yaml` is missing the `type` field for some properties.

**Incorrect (outputs/aws_cloud_account/outputs.yaml):**
```yaml
properties:
  attributes:
    type: object
    properties:
      aws_region:
        type: string
  interfaces:
    # Missing 'type: object' here!
    properties:
      ...
```

**Correct:**
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

---

### Issue: Union Types Not Supported
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

## 8. patternProperties Required Field Indentation

### Error Pattern
```
sample.spec does not comply with module's spec schema: Validation error at '': doesn't validate with schema://sample.spec.json#
Details:
  - /rules: missing properties: 'service_name', 'path', 'port'
```

### Issue: `required` Array at Wrong Indentation Level
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

## 10. Terraform Validation Errors

### Error Pattern
```
terraform validate failed: terraform validation failed with X error(s)
Reference to undeclared input variable: An input variable with the name "X" has not been declared.
```

### Issue: Undeclared Variables
**Module:** `k8s_callback/k8s_standard`

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

## 11. Nested Duplicate Enum Values

### Error Pattern
```
'/properties/X/patternProperties/.../properties/Y/enum' does not validate with .../uniqueItems: items at index N and M are equal
```

### Issue: Duplicate Enum in Nested Structure
**Module:** `ingress/nginx_k8s`

**Problem:** The duplicate enum exists not only at the top level but also in nested `patternProperties` structures like `rules.*.more_set_headers.*.header_name`.

**Location:** `spec.rules.{pattern}.more_set_headers.{pattern}.header_name`

**Rule:** Check ALL occurrences of enum arrays in the schema, including those in nested patternProperties.

---

## 12. Nested Invalid Regex Patterns

### Error Pattern
```
'/properties/sidecars/patternProperties/.../properties/port/pattern' does not validate with .../pattern/format: '...' is not valid 'regex'
```

### Issue: Invalid Regex in Nested Structure
**Module:** `service/aws`

**Problem:** The invalid regex pattern exists not only in the main `ports` section but also in nested structures like `sidecars.*.runtime.ports.*.port`.

**Rule:** When fixing regex patterns, search for ALL occurrences of the pattern in the file, including nested structures.

---

## Summary Table

| Error Type | Count | Modules Affected |
|------------|-------|------------------|
| Sample.spec validation | 4 | cloud_account/aws_provider, kubernetes_cluster/eks, helm/k8s_standard, prometheus/k8s_standard |
| Invalid regex patterns | 2 | service/aws (main + sidecars), ingress/nginx_k8s |
| Duplicate enum values | 1 | ingress/nginx_k8s (top-level + nested in rules) |
| Remote module references | 6 | artifactories/standard, cert_manager/standard, config_map/k8s_standard, k8s_resource/k8s_standard, kubernetes_secret/k8s_standard |
| required_providers block | 1 | k8s_callback/k8s_standard |
| var.inputs type=any | 2 | helm/k8s_standard, prometheus/k8s_standard |
| Output schema issues | 3 | kubernetes_cluster/eks, kubernetes_node_pool/aws, network/aws_vpc |
| patternProperties required indentation | 1 | ingress/nginx_k8s |
| var.instance.spec | 1 | vpa/standard |
| Terraform validation | 1 | k8s_callback/k8s_standard |

---

## Quick Reference: Validation Checklist

Before publishing a module, verify:

- [ ] Sample.spec includes all required fields with valid values
- [ ] Sample values match enum constraints
- [ ] Use `{}` for object types, `[]` for array types (never `null`)
- [ ] Regex patterns avoid lookahead/lookbehind (check ALL occurrences including nested structures)
- [ ] Enum arrays have no duplicates (check ALL occurrences including nested patternProperties)
- [ ] `required` arrays in patternProperties are correctly indented (inside pattern, not sibling)
- [ ] No external module sources (use local paths only)
- [ ] No `required_providers` block in terraform files
- [ ] `var.inputs` has explicit object type (not `any` or `map(any)`)
- [ ] Output schemas have `type: object` for all object properties
- [ ] Output schemas use simple types (no union types like `["string", "null"]`)
- [ ] `var.instance.spec` types match facets.yaml schema exactly
- [ ] All referenced variables are declared in variables.tf
