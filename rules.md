# Facets Module Validation Rules

This document contains validation rules for Facets modules. Each rule includes bad and good examples.

---

## Sample.spec Rules

### RULE-001: Required fields must be present

All required fields from spec schema must exist in sample, even with empty values.

**Bad:**
```yaml
sample:
  spec: {}
```

**Good:**
```yaml
sample:
  spec:
    cloud_account: ""
    region: ""
```

---

### RULE-002: Enum values must match schema

Sample values must be valid enum options defined in the spec schema.

**Bad:**
```yaml
sample:
  spec:
    cluster_addons:
      addon1:
        name: metrics-server  # Not in allowed enum
```

**Good:**
```yaml
sample:
  spec:
    cluster_addons:
      addon1:
        name: eks-node-agent  # Valid enum value
```

---

### RULE-003: Use {} for objects, [] for arrays, never null

When schema defines `type: object`, use `{}`. When schema defines `type: array`, use `[]`. Never use `null`.

**Bad:**
```yaml
sample:
  spec:
    values: null
    tolerations: []  # Wrong if schema says type: object
```

**Good:**
```yaml
sample:
  spec:
    values: {}
    tolerations: {}  # Correct for type: object with patternProperties
```

---

## var.inputs Rules

### Finding Input/Output Type Schemas

To build correct `var.inputs` types, you need to know the schema of each input type. Two ways to find it:

1. **From `outputs/` directory:**
   ```
   outputs/{type-name}/outputs.yaml
   ```
   Example: For `@facets/aws_cloud_account`, check `outputs/aws_cloud_account/outputs.yaml`

2. **Using raptor CLI:**
   ```bash
   raptor get output-type @facets/aws_cloud_account
   ```

---

### RULE-004: Explicit object type required

`var.inputs` must use explicit `object({...})`, NOT `type = any` or `map(any)`.

**Bad:**
```hcl
variable "inputs" {
  type = any
}

variable "inputs" {
  type = map(any)
}
```

**Good:**
```hcl
variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = optional(object({
        region = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}
```

---

### RULE-005: All facets.yaml inputs must exist in var.inputs

Every input declared in facets.yaml must have a corresponding entry in var.inputs.

**facets.yaml:**
```yaml
inputs:
  cloud_account:
    type: "@facets/aws_cloud_account"
  kubernetes_details:
    type: "@facets/eks"
```

**Bad (missing kubernetes_details):**
```hcl
variable "inputs" {
  type = object({
    cloud_account = object({...})
    # kubernetes_details is missing!
  })
}
```

**Good:**
```hcl
variable "inputs" {
  type = object({
    cloud_account = object({...})
    kubernetes_details = object({
      attributes = optional(object({...}), {})
      interfaces = optional(object({}), {})
    })
  })
}
```

---

### RULE-006: Use attributes/interfaces structure

All inputs must follow the standard `attributes`/`interfaces` pattern, not flat structure.

**Bad:**
```hcl
variable "inputs" {
  type = object({
    aks_cluster = object({
      oidc_issuer_url = optional(string)  # Flat structure!
      cluster_id = optional(string)
    })
  })
}
```

**Good:**
```hcl
variable "inputs" {
  type = object({
    aks_cluster = object({
      attributes = optional(object({
        oidc_issuer_url = optional(string)
        cluster_id = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}
```

---

## Spec Schema Rules

### RULE-007: No regex lookahead/lookbehind

JSON Schema regex does not support `(?=)`, `(?!)`, `(?<=)`, `(?<!)`.

**Bad:**
```yaml
properties:
  port:
    type: string
    pattern: ^(?!0$)([1-9][0-9]{0,3}|[1-5][0-9]{4})$
```

**Good:**
```yaml
properties:
  port:
    type: string
    pattern: ^([1-9][0-9]{0,3}|[1-5][0-9]{4})$
```

**Bad (domain validation):**
```yaml
pattern: ^(?=.{1,253}$)(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\..*)?$
```

**Good:**
```yaml
pattern: ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$
```

---

### RULE-008: No duplicate enum values

Enum arrays must not contain duplicate values.

**Bad:**
```yaml
properties:
  header_name:
    enum:
      - X-Frame-Options
      - Cache-Control
      - Cache-Control  # Duplicate!
      - Vary
```

**Good:**
```yaml
properties:
  header_name:
    enum:
      - X-Frame-Options
      - Cache-Control
      - Vary
```

---

### RULE-009: required inside patternProperties

Place `required` array inside the pattern definition, not as a sibling of `patternProperties`.

**Bad:**
```yaml
rules:
  type: object
  patternProperties:
    ^[a-zA-Z0-9_.-]*$:
      type: object
      properties:
        service_name: {type: string}
        path: {type: string}
        port: {type: string}
  required:  # Wrong! This is sibling of patternProperties
    - service_name
    - path
    - port
```

**Good:**
```yaml
rules:
  type: object
  patternProperties:
    ^[a-zA-Z0-9_.-]*$:
      type: object
      properties:
        service_name: {type: string}
        path: {type: string}
        port: {type: string}
      required:  # Correct! Inside the pattern definition
        - service_name
        - path
        - port
```

---

## Output Schema Rules

### RULE-010: Explicit type: object for nested objects

Every nested object in output schema must have explicit `type: object` field.

**Bad:**
```yaml
# outputs/my-type/outputs.yaml
attributes:
  properties:
    region:
      type: string
```

**Good:**
```yaml
# outputs/my-type/outputs.yaml
attributes:
  type: object
  properties:
    region:
      type: string
```

---

### RULE-011: No union types

Don't use array syntax for types in output schemas.

**Bad:**
```yaml
properties:
  vpc_endpoint_id:
    type:
      - string
      - "null"
```

**Good:**
```yaml
properties:
  vpc_endpoint_id:
    type: string
```

---

### RULE-012: Field names must match actual outputs

Output schema field names must match what the module actually outputs in `locals.tf`.

**Bad (schema says `project` but module outputs `project_id`):**
```yaml
# outputs.yaml
attributes:
  type: object
  properties:
    project:
      type: string
```

```hcl
# locals.tf
output_attributes = {
  project_id = data.google_project.current.project_id
}
```

**Good:**
```yaml
# outputs.yaml
attributes:
  type: object
  properties:
    project_id:
      type: string
```

```hcl
# locals.tf
output_attributes = {
  project_id = data.google_project.current.project_id
}
```

---

## Terraform Rules

### RULE-013: No required_providers in modules

Modules should not define `required_providers` blocks. Providers are injected by the Facets platform.

**Bad:**
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

**Good:**
```hcl
terraform {
  required_version = ">= 1.0"
}
```

---

### RULE-014: All referenced variables must be declared

Every variable referenced in Terraform code must be declared in `variables.tf`.

**Bad:**
```hcl
# main.tf
resource "kubernetes_namespace" "ns" {
  metadata {
    name = var.cc_metadata.namespace  # cc_metadata not declared!
  }
}
```

**Good:**
```hcl
# variables.tf
variable "instance" {
  type = object({
    spec = object({
      namespace = optional(string)
    })
  })
}

# main.tf
resource "kubernetes_namespace" "ns" {
  metadata {
    name = var.instance.spec.namespace
  }
}
```

---

### RULE-015: Prohibited platform-injected variables

The following legacy platform-injected variables are **PROHIBITED** and must never be used in modules:
- `var.cc_metadata`
- `var.cluster`
- `var.baseinfra`

Raptor validation will flag and fail modules using these variables.

**Bad:**
```hcl
# Using prohibited variables
resource "null_resource" "callback" {
  provisioner "local-exec" {
    command = "curl https://${var.cc_metadata.cc_host}/api"
  }
}

locals {
  cluster_id = var.cluster.id
}
```

**Good - For null_resource (use env vars directly):**
```hcl
# Access TF_VAR_* environment variables directly in shell commands
resource "null_resource" "callback" {
  provisioner "local-exec" {
    command = "curl https://$TF_VAR_cc_host/api -H \"Authorization: Bearer $TF_VAR_cc_auth_token\""
  }
}
```

**Good - For Terraform resources (use data external):**
```hcl
# Use data external to read environment variables
data "external" "env" {
  program = ["sh", "-c", "echo '{\"cc_host\":\"'$TF_VAR_cc_host'\",\"cc_auth_token\":\"'$TF_VAR_cc_auth_token'\"}'"]
}

locals {
  cc_host       = data.external.env.result.cc_host
  cc_auth_token = data.external.env.result.cc_auth_token
}
```

**Available environment variables:**

| Env Variable | Description |
|--------------|-------------|
| `TF_VAR_cc_host` | Control plane host |
| `TF_VAR_cc_auth_token` | Control plane auth token |
| `TF_VAR_cc_region` | Region |
| `TF_VAR_cc_vpc_id` | VPC ID |
| `TF_VAR_cc_vpc_cidr` | VPC CIDR |
| `TF_VAR_cc_tf_state_bucket` | Terraform state bucket |
| `TF_VAR_cc_tf_state_region` | Terraform state region |
| `TF_VAR_cc_tf_dynamo_table` | DynamoDB lock table |
| `TF_VAR_cc_tenant_provider` | Tenant cloud provider |
| `TF_VAR_tenant_base_domain` | Tenant base domain |
| `TF_VAR_tenant_base_domain_id` | Tenant base domain hosted zone ID |

---

## Quick Reference

| Rule | Category | Summary |
|------|----------|---------|
| RULE-001 | sample.spec | Required fields must be present |
| RULE-002 | sample.spec | Enum values must match schema |
| RULE-003 | sample.spec | Use {} for objects, [] for arrays |
| RULE-004 | var.inputs | Explicit object type required |
| RULE-005 | var.inputs | All facets.yaml inputs must exist |
| RULE-006 | var.inputs | Use attributes/interfaces structure |
| RULE-007 | spec schema | No regex lookahead/lookbehind |
| RULE-008 | spec schema | No duplicate enum values |
| RULE-009 | spec schema | required inside patternProperties |
| RULE-010 | output schema | Explicit type: object for nested |
| RULE-011 | output schema | No union types |
| RULE-012 | output schema | Field names match actual outputs |
| RULE-013 | terraform | No required_providers in modules |
| RULE-014 | terraform | All variables must be declared |
| RULE-015 | terraform | No cc_metadata, cluster, baseinfra vars |
