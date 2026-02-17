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

Every variable referenced in Terraform code must be declared in `variables.tf`. Platform-injected variables like `var.cc_metadata`, `var.cluster`, `var.baseinfra` do not exist in modules — use `var.instance` and `var.inputs` instead.

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

## Real-World Bug Rules

The following rules are derived from actual bugs found in production modules. Each references the issue/PR where the bug was discovered.

---

### RULE-015: Use lookup() for optional spec fields

**Source:** #211, #206, #238
**Category:** Terraform

Accessing optional spec fields directly causes Terraform errors when the field is not provided. Always use `lookup()` with a sensible default.

**Bad:**
```hcl
# Fails when metadata is not present in spec
namespace = var.instance.metadata.namespace

# Fails when interruption_handling is not in spec
enable_interruption = var.instance.spec.interruption_handling
```

**Good:**
```hcl
namespace = lookup(lookup(var.instance, "metadata", {}), "namespace", "default")

enable_interruption = lookup(var.instance.spec, "interruption_handling", false)
```

---

### RULE-016: Match input access pattern to the output type schema

**Source:** #228, #233, #208, #224
**Category:** var.inputs

The structure of `var.inputs.<name>` is determined by the output type schema being consumed. You **must** verify the actual structure by checking the output type definition (in `outputs/{type-name}/outputs.yaml` or via `raptor get output-type <type>`).

Common mistake: assuming all output types have the same nesting structure. Some types wrap data in `.attributes`, others may have fields at different levels. Always verify.

**Bad (assuming structure without checking output type):**
```hcl
# If @facets/kubernetes-details puts cluster_endpoint inside attributes:
host = var.inputs.kubernetes_details.cluster_endpoint  # Wrong level!
```

**Good (verified against output type schema):**
```hcl
# Check: raptor get output-type @facets/kubernetes-details
# Schema shows: attributes.cluster_endpoint
host = var.inputs.kubernetes_details.attributes.cluster_endpoint
```

**Also applies to blueprints:** When consuming non-default output keys, you must specify `"output_name"` in the blueprint input wiring:

**Bad:**
```json
{
  "inputs": {
    "kubernetes_details": {
      "resourceType": "kubernetes_cluster",
      "resourceName": "default"
    }
  }
}
```

**Good (when consuming the `attributes` output key):**
```json
{
  "inputs": {
    "kubernetes_details": {
      "resourceType": "kubernetes_cluster",
      "resourceName": "default",
      "output_name": "attributes"
    }
  }
}
```

---

### RULE-017: Avoid unnecessary explicit depends_on

**Source:** #210
**Category:** Terraform

Adding `depends_on` to a resource that already implicitly depends on another resource (via attribute references) creates redundant dependency edges. In some cases, this can cause Terraform cycles.

**Bad:**
```hcl
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.main.name  # Already implicit dependency
  depends_on   = [aws_eks_cluster.main]      # Unnecessary and can cause cycles
}
```

**Good:**
```hcl
resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.main.name  # Terraform infers dependency automatically
}
```

**When `depends_on` IS needed:** See RULE-018 for cases where no attribute reference exists.

---

### RULE-018: CRD resources must depend on their Helm release

**Source:** #200
**Category:** Terraform

Terraform resources that use Custom Resource Definitions (CRDs) installed by a Helm chart will fail if the Helm release hasn't completed. Since there's no attribute reference to create an implicit dependency, an explicit `depends_on` is required.

**Bad:**
```hcl
resource "kubectl_manifest" "karpenter_nodepool" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    # ...
  })
  # Missing depends_on - CRD may not exist yet!
}
```

**Good:**
```hcl
resource "kubectl_manifest" "karpenter_nodepool" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    # ...
  })
  depends_on = [helm_release.karpenter]  # Ensure CRDs are installed first
}
```

---

### RULE-019: Pin Docker images to verified tags

**Source:** #204, #201
**Category:** Terraform

Using non-existent image tags causes `ImagePullBackOff` errors. Using `:latest` breaks reproducibility. Always use verified, pinned image tags from official registries.

**Bad:**
```hcl
# Tag doesn't exist on this registry
image = "bitnami/kubectl:1.31.4"

# Latest tag breaks reproducibility
image = "kubectl:latest"
```

**Good:**
```hcl
# Verified official image with correct tag format
image = "registry.k8s.io/kubectl:v1.31.4"
```

**Verification:** Before using an image tag, verify it exists:
```bash
# Check if tag exists
docker manifest inspect registry.k8s.io/kubectl:v1.31.4
```

---

### RULE-020: Single owner for shared resource tags

**Source:** #234
**Category:** Terraform

When multiple modules manage the same tag on a shared resource (e.g., subnets), Terraform oscillates between states on every apply. Only the resource-owning module should manage its tags.

**Bad (two modules setting the same tag on a shared subnet):**
```hcl
# In network module
resource "aws_subnet" "private" {
  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# In karpenter module - CONFLICT!
resource "aws_ec2_tag" "subnet_discovery" {
  resource_id = data.aws_subnet.private.id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}
```

**Good (only the resource owner manages the tag):**
```hcl
# In network module - single owner of subnet tags
resource "aws_subnet" "private" {
  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# Karpenter module reads the subnet via data source, does NOT manage its tags
data "aws_subnets" "private" {
  filter {
    name   = "tag:karpenter.sh/discovery"
    values = [var.cluster_name]
  }
}
```

---

### RULE-021: No unsupported metadata in facets.yaml

**Source:** #212
**Category:** facets.yaml

`metadata:` is not a supported top-level key in facets.yaml. Do not define metadata schemas or include metadata in sample blocks. Use `var.environment.namespace` for namespace access instead.

**Bad:**
```yaml
# Root-level metadata schema - NOT SUPPORTED
metadata:
  type: object
  properties:
    namespace:
      type: string

sample:
  kind: service
  flavor: aws
  metadata:          # NOT SUPPORTED in sample
    namespace: test
  spec:
    replicas: 1
```

**Good:**
```yaml
# No metadata at root level or in sample
sample:
  kind: service
  flavor: aws
  spec:
    replicas: 1

# In Terraform, use var.environment for namespace:
# namespace = var.environment.namespace
```

---

### RULE-022: facets.yaml must include intentDetails

**Source:** #153, #185
**Category:** facets.yaml

Every facets.yaml must include an `intentDetails` block. Missing `intentDetails` causes UI rendering issues and validation warnings.

**Bad:**
```yaml
intent: service
flavor: aws
version: "1.0"
description: Deploy a service on AWS
# Missing intentDetails!
```

**Good:**
```yaml
intent: service
flavor: aws
version: "1.0"
description: Deploy a service on AWS
intentDetails:
  type: Cloud & Infrastructure
  description: Deploy and manage containerized applications
  displayName: Service
  iconUrl: https://raw.githubusercontent.com/Facets-cloud/facets-modules/master/icons/service.svg
```

**Valid `intentDetails.type` values:**
- `Cloud & Infrastructure`
- `Managed Datastores`
- `Kubernetes`
- `Monitoring & Observability`
- `Operators`

---

### RULE-023: Enable security defaults

**Source:** #218
**Category:** Module design

Security features like encryption, logging, and monitoring should be enabled by default. Users can opt out explicitly, but the default should be secure.

**Bad:**
```hcl
# Encryption disabled by default - insecure
enable_encryption = lookup(var.instance.spec, "enable_encryption", false)

# No logging by default
enable_logging = lookup(var.instance.spec, "enable_logging", false)
```

**Good:**
```hcl
# Encryption enabled by default - secure
enable_encryption = lookup(var.instance.spec, "enable_encryption", true)

# Logging enabled by default
enable_logging = lookup(var.instance.spec, "enable_logging", true)
```

---

### RULE-024: Bump version for breaking changes and update project types

**Category:** Module lifecycle

When introducing a breaking change to a module (e.g., changing input/output types, renaming spec fields, removing features), increment the version by `0.1` in `facets.yaml`. The directory name stays the same — only the `version:` field in facets.yaml changes. If the module is referenced in any base project type (`project-type/{cloud}/project-type.yml`), update the version there too.

**Bad (breaking change without version bump):**
```yaml
# facets.yaml - changed output type but kept same version
intent: kubernetes_cluster
flavor: eks_standard
version: "1.0"          # Still 1.0 despite breaking output change!
outputs:
  default:
    type: "@facets/eks-v2"   # Was @facets/eks — breaking change
```

**Good (version bumped, project type updated):**
```yaml
# facets.yaml
intent: kubernetes_cluster
flavor: eks_standard
version: "1.1"          # Bumped from 1.0 to 1.1
outputs:
  default:
    type: "@facets/eks-v2"
```

```yaml
# project-type/aws/project-type.yml — updated to use new version
- intent: kubernetes_cluster
  flavor: eks_standard
  version: "1.1"        # Was "1.0", updated to match
```

**What counts as a breaking change:**
- Changing an output type (consumers may break)
- Removing or renaming a spec field
- Changing input types or removing inputs
- Altering output attribute/interface structure

**What does NOT require a version bump:**
- Adding new optional spec fields
- Bug fixes that don't change the contract
- Adding new outputs (existing consumers unaffected)

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
| RULE-014 | terraform | All variables must be declared; no platform-injected vars |
| RULE-015 | terraform | Use lookup() for optional spec fields |
| RULE-016 | var.inputs | Match input access pattern to output type schema |
| RULE-017 | terraform | Avoid unnecessary explicit depends_on |
| RULE-018 | terraform | CRD resources must depend on their Helm release |
| RULE-019 | terraform | Pin Docker images to verified tags |
| RULE-020 | terraform | Single owner for shared resource tags |
| RULE-021 | facets.yaml | No unsupported metadata in facets.yaml |
| RULE-022 | facets.yaml | facets.yaml must include intentDetails |
| RULE-023 | module design | Enable security defaults (encryption, logging) |
| RULE-024 | module lifecycle | Bump version for breaking changes; update project types |
