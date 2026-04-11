---
title: "Facets YAML Schema Design"
description: "Create and modify facets.yaml files correctly with complete schema design, x-ui tags, validation rules, and UI customization. Auto-loads when working with facets.yaml."
triggers: ["facets.yaml", "facets yaml", "x-ui", "spec schema", "intentDetails", "module schema"]
auto_load_patterns: ["**/facets.yaml"]
version: "1.0"
available_in_modes: ["facets"]
category: "development"
tags: ["facets", "yaml", "schema", "ui", "validation", "module"]
icon: "file-code"
---

# Facets YAML Schema Design Guide

A comprehensive reference for creating and modifying `facets.yaml` files with correct schema design, UI customization, and validation.

---

## Table of Contents

1. [Overview](#1-overview)
2. [facets.yaml Structure](#2-facetsyaml-structure)
3. [Required Top-Level Fields](#3-required-top-level-fields)
4. [Spec Schema Design](#4-spec-schema-design)
5. [UI Extensions (x-ui Tags)](#5-ui-extensions-x-ui-tags)
6. [Inputs and Outputs](#6-inputs-and-outputs)
7. [Sample Configuration](#7-sample-configuration)
8. [Validation Rules](#8-validation-rules)
9. [Common Patterns](#9-common-patterns)
10. [Quick Reference](#10-quick-reference)

---

## 1. Overview

### What is facets.yaml?

`facets.yaml` is the metadata and schema definition file for Facets modules. It:
- Defines the module's identity (intent, flavor, version)
- Declares the developer-facing configuration schema (spec)
- Specifies inputs (dependencies) and outputs (what it provides)
- Controls UI rendering and validation
- Includes sample configurations

### Key Principles

1. **Complete Schema Definition**: Never use `type: any` - always define complete schemas
2. **UI-First Design**: Use x-ui tags to create intuitive forms
3. **Validation**: Use JSON Schema patterns, enums, and custom error messages
4. **Type Safety**: Inputs and outputs must use well-defined output types
5. **Developer Experience**: Provide helpful placeholders, tooltips, and error messages

---

## 2. facets.yaml Structure

```yaml
# Module Identity
intent: <technology_name>
flavor: <implementation_variant>
version: "<semantic_version>"
description: <one_line_description>

# Intent Details (REQUIRED)
intentDetails:
  type: <category>
  description: <detailed_description>
  displayName: <human_readable_name>
  iconUrl: <svg_icon_url>

# Cloud Support
clouds:
  - aws
  - gcp
  - azure
  - kubernetes

# Artifact Configuration (optional)
artifact_inputs:
  primary:
    attribute_path: spec.release.image
    artifact_type: docker_image

# Control Plane Settings (optional): This is required for any module that has Kubernetes-related functionality and wants to leverage the Kubernetes Explorer in the Control Plane UI.
controlPlaneUISettings:
  enableKubernetesExplorer: true

# Inputs (dependencies)
inputs:
  <input_name>:
    type: "@facets/<output_type>"
    displayName: <human_readable_name>
    description: <what_this_input_provides>
    optional: <true|false>
    default:
      resource_type: <type>
      resource_name: <name>
    providers:
      - <provider_name>

# Outputs (what this module provides)
outputs:
  default:
    type: "@facets/<output_type>"
    title: <output_description>
  attributes:
    type: "@facets/<output_type>"
    title: <output_description>
    providers:
      <provider_name>:
        source: <provider_source>
        version: <provider_version>
        attributes:
          <attribute_name>: <path_to_value>

# Spec Schema (JSON Schema)
spec:
  title: <schema_title>
  description: <schema_description>
  type: object
  x-ui-order:
    - <field_order>
    # field_name 
    # field_name 
    # ...
  properties:
    <field_name>:
      type: <string|number|boolean|object|array>
      title: <field_title>
      description: <field_description>
      # ... JSON Schema validations and x-ui tags

# Sample Configuration
sample:
  kind: <intent>
  flavor: <flavor>
  version: "<version>"
  disabled: false
  spec:
    # Sample spec values
```

---

## 3. Required Top-Level Fields

### 3.1 Module Identity

```yaml
intent: postgres                    # Technology/purpose
flavor: aws-rds                     # Implementation variant
version: "1.0"                      # Semantic version (quoted)
description: Managed PostgreSQL database using Amazon RDS
```

### 3.2 intentDetails (REQUIRED)

**IMP**: Every facets.yaml MUST include intentDetails.

```yaml
intentDetails:
  type: Datastores                  # Category (see valid types below)
  description: AWS RDS PostgreSQL managed database service
  displayName: PostgreSQL           # Display name for UI
  iconUrl: https://raw.githubusercontent.com/Facets-cloud/facets-modules-redesign/main/icons/postgres.svg
```

**Valid intentDetails.type values:**
- `Cloud & Infrastructure`
- `Datastores`
- `Kubernetes`
- `Monitoring & Observability`
- `Operators`

### 3.3 Clouds

```yaml
clouds:
  - aws    # Specify all clouds this module supports
```

---

## 4. Spec Schema Design

### 4.1 JSON Schema Basics

Use standard JSON Schema with these conventions:

```yaml
spec:
  type: object
  title: Database Configuration
  description: Configure your PostgreSQL database

  # Control field order with x-ui-order
  x-ui-order:
    - version_config
    - sizing
    - security_config

  properties:
    version_config:
      type: object
      title: Version & Basic Configuration
      properties:
        engine_version:
          type: string
          title: PostgreSQL Version
          description: Version of the PostgreSQL database engine
          enum:
            - "14.21"
            - "15.16"
            - "16.12"
          default: "16.12"
      required:
        - engine_version
```

### 4.2 Field Types

**String:**
```yaml
database_name:
  type: string
  title: Database Name
  description: Name of the initial database to create
  pattern: ^[a-zA-Z][a-zA-Z0-9_]*$
  minLength: 1
  maxLength: 63
  default: postgres
  x-ui-placeholder: mydb
```

**Number:**
```yaml
allocated_storage:
  type: number
  title: Allocated Storage (GB)
  description: Initial storage allocation in GB
  minimum: 20
  maximum: 65536
  default: 100
```

**Boolean:**
```yaml
deletion_protection:
  type: boolean
  title: Enable Deletion Protection
  description: Protect database from accidental deletion
  default: true
```

**Object:**
```yaml
sizing:
  type: object
  title: Sizing & Performance
  x-ui-order:
    - instance_class
    - allocated_storage
  properties:
    instance_class:
      type: string
      enum: [db.t3.small, db.m5.large]
  required:
    - instance_class
```

**Array:**
```yaml
ports:
  type: array
  title: Ports
  items:
    type: object
    properties:
      port:
        type: integer
        title: Port Number
        minimum: 1
        maximum: 65535
        x-ui-unique: true
    required:
      - port
```

### 4.3 Pattern Properties

For dynamic keys (maps):

```yaml
tolerations:
  type: object
  title: Tolerations
  patternProperties:
    ^[a-zA-Z0-9_.-]*$:
      type: object
      properties:
        key:
          type: string
        operator:
          type: string
          enum: [Equal, Exists]
      required:
        - key
        - operator
```

**IMPORTANT**: Place `required` array INSIDE the pattern definition, not as a sibling.

### 4.4 Validation Rules

**No lookahead/lookbehind (IMP):**
```yaml
# BAD
pattern: ^(?!0$)([1-9][0-9]{0,3})$

# GOOD
pattern: ^([1-9][0-9]{0,3})$
```

**No duplicate enums:**
```yaml
# BAD
enum: [X-Frame-Options, Cache-Control, Cache-Control]

# GOOD
enum: [X-Frame-Options, Cache-Control, Vary]
```

---

## 5. UI Extensions (x-ui Tags)

### 5.1 Display Control

#### x-ui-order
Controls the display order of fields.

```yaml
spec:
  type: object
  x-ui-order:
    - version_config
    - sizing
    - security_config
  properties:
    # Fields appear in the order specified above
```

#### x-ui-toggle
Renders a group of fields as a collapsible section. For example, show health check settings inside a deployment only if the user chooses to enable health checks.

```yaml
cloud_permissions:
  type: object
  title: Cloud Permissions
  description: Assign roles, define access levels
  x-ui-toggle: false
  properties:
    aws:
    type: object
    title: AWS
    x-ui-toggle: true
```

#### x-ui-placeholder
Provides example text in input fields.

```yaml
database_name:
  type: string
  title: Database Name
  x-ui-placeholder: my-database
```

#### x-ui-skip
Hides a field from the UI (programmatically set).

```yaml
internal_id:
  type: string
  x-ui-skip: true
```

#### x-ui-immutable
Marks a field as read-only after initial creation. The field can be set when first creating the resource but cannot be modified afterwards.

```yaml
engine_type:
  type: string
  title: Engine Type
  x-ui-immutable: true
  enum:
    - postgres
    - mysql
```

### 5.2 Conditional Display

#### x-ui-visible-if
Shows/hides fields based on other field values.

```yaml
restart_policy:
  type: string
  title: Restart Policy
  x-ui-visible-if:
    field: spec.type
    values:
      - application
      - statefulset
  enum: [Always, OnFailure, Never]
```

**Multiple conditions:**
```yaml
backup_retention:
  type: number
  x-ui-visible-if:
    - field: spec.enable_backups
      values: [true]
    - field: spec.backup_type
      values: [automated]
```

### 5.3 Override Control

#### x-ui-overrides-only
Field only editable at environment level, not blueprint level.

```yaml
region:
  type: string
  title: Region
  x-ui-overrides-only: true
  x-ui-api-source:
    endpoint: /cc-ui/v1/dropdown/aws/regions
```

#### x-ui-override-disable
Field only editable at blueprint level, locked from environment changes.

```yaml
image_pull_secrets:
  type: array
  title: Image Pull Secrets
  x-ui-override-disable: true
```

#### x-ui-critical
Marks a field as critical, requiring the `CRITICAL_RESOURCE_WRITE` permission to modify. Used for dangerous or high-impact settings.

```yaml
force_destroy:
  type: boolean
  title: Force Destroy
  description: Allow destroying the resource even if it contains data
  x-ui-critical: true
  default: false
```

### 5.4 Data Sources

#### x-ui-dynamic-enum
Creates dropdown from values elsewhere in the spec.

```yaml
readiness_port:
  type: integer
  title: Readiness Port
  x-ui-dynamic-enum: spec.runtime.ports.*.port
  x-ui-disable-tooltip: No Ports Added
```

#### x-ui-api-source
Populates dropdown from API endpoint.

```yaml
instance_class:
  type: string
  title: Instance Class
  x-ui-api-source:
    endpoint: /cc-ui/v1/dropdown/aws/rds/instance-classes
    method: GET
    params:
      engine: postgres
    labelKey: name
    valueKey: value
    filterConditions:
      - field: type
        value: current-generation
  x-ui-typeable: true
```

**With dynamic properties and regex lookup:**
```yaml
service_name:
  type: string
  title: Service Name
  x-ui-api-source:
    endpoint: /cc-ui/v1/dropdown/stack/{{stackName}}/service/{{serviceName}}/overview
    dynamicProperties:
      serviceName:
        key: service_name
        lookup: regex
        x-ui-lookup-regex: \${[^.]+\.([^.]+).*
  valueTemplate: ${service.{{value}}.out.attributes.name}
```

#### x-ui-output-type
Filters resources by output type.

```yaml
arn:
  type: string
  title: IAM Policy ARN
  x-ui-output-type: iam_policy_arn
  x-ui-typeable: true
```

#### x-ui-secret-ref
Marks field as secret reference (from secret store).

```yaml
git_token:
  type: string
  title: Git Token
  x-ui-secret-ref: true
  x-ui-placeholder: Select or enter secret reference
```

#### x-ui-variable-ref
Marks field as variable reference (from variable store).

```yaml
api_key:
  type: string
  title: API Key
  x-ui-variable-ref: true
  x-ui-placeholder: Select or enter variable reference
```

#### x-ui-typeable
Allows manual typing in addition to dropdown selection.

```yaml
cluster_name:
  type: string
  title: Cluster Name
  x-ui-api-source:
    endpoint: /cc-ui/v1/dropdown/eks/clusters
  x-ui-typeable: true
```

#### x-ui-artifact
Renders an artifact reference picker widget. Used for fields that reference build artifacts (Docker images, zip bundles, etc.).

```yaml
image:
  type: string
  title: Container Image
  x-ui-artifact: true
  x-ui-placeholder: Select an artifact
```

#### x-ui-output / x-ui-output-type
Renders an output reference picker widget that filters available resources by output type via API.

```yaml
database_url:
  type: string
  title: Database Connection
  x-ui-output: true
  x-ui-output-type: postgres
```

### 5.5 Validation & Errors

#### x-ui-error-message
Custom error message for validation failures.

```yaml
cpu_limit:
  type: string
  title: CPU Limit
  pattern: ^([0-9]+m|[0-9]+(\.[0-9]+)?)$
  x-ui-error-message: Value must be in format like 100m or 0.5
```

#### x-ui-compare
Compares field value against another field.

```yaml
cpu_request:
  type: string
  title: CPU Request
  x-ui-compare:
    field: spec.resources.cpu_limit
    comparator: <=
    x-ui-error-message: CPU request cannot exceed CPU limit
```

**Comparators:** `<`, `<=`, `>`, `>=`, `==`, `!=`

#### x-ui-unique
Enforces uniqueness in array values.

```yaml
port:
  type: integer
  title: Port
  x-ui-unique: true
  x-ui-error-message: Port numbers must be unique
```

#### x-ui-array-input-validation
Defines validation rules for array item inputs, allowing custom constraints on array elements.

```yaml
allowed_origins:
  type: array
  title: Allowed Origins
  x-ui-array-input-validation:
    pattern: ^https?://
    errorMessage: Must be a valid URL starting with http:// or https://
  items:
    type: string
```

#### x-ui-unique-pattern-error-message
Custom error message displayed when a uniqueness constraint violation is detected on a pattern-matched field.

```yaml
route_path:
  type: string
  title: Route Path
  x-ui-unique: true
  x-ui-unique-pattern-error-message: This route path is already in use
  pattern: ^/[a-z0-9/-]*$
```

### 5.6 Editor Types

#### x-ui-yaml-editor
Renders a YAML editor for complex objects.

```yaml
values: ## OR helm_values, where the user needs to input YAML content
  type: object
  title: Helm Values
  x-ui-yaml-editor: true
```

#### x-ui-textarea
Renders a multiline text area.

```yaml
description:
  type: string
  title: Description
  x-ui-textarea: true
  x-ui-placeholder: Enter detailed description
```

#### x-ui-command
Special handling for command arrays.

```yaml
command:
  type: array
  title: Command
  x-ui-command: true
  items:
    type: string
```

#### x-ui-editor / x-ui-editor-language
Renders a Monaco code editor widget. Use `x-ui-editor: true` to enable and `x-ui-editor-language` to set the syntax highlighting language.

```yaml
custom_config:
  type: string
  title: Custom Configuration
  x-ui-editor: true
  x-ui-editor-language: json
```

#### x-ui-radio
Renders enum options as radio buttons instead of a dropdown.

```yaml
deployment_strategy:
  type: string
  title: Deployment Strategy
  x-ui-radio: true
  enum:
    - RollingUpdate
    - Recreate
```

#### x-ui-multi-select
Renders a multi-select dropdown allowing multiple values to be chosen.

```yaml
availability_zones:
  type: array
  title: Availability Zones
  x-ui-multi-select: true
  items:
    type: string
    enum:
      - us-east-1a
      - us-east-1b
      - us-east-1c
```

### 5.7 Advanced UI Features

#### x-ui-no-sort
Preserves enum order (no alphabetical sorting).

```yaml
priority:
  type: string
  title: Priority
  x-ui-no-sort: true
  enum:
    - None
    - Low
    - Medium
    - High
    - Critical
```

#### x-ui-show-label-selected
Shows label instead of value in UI.

```yaml
account_id:
  type: string
  title: Account ID
  x-ui-show-label-selected: true
  x-ui-api-source:
    endpoint: /cc-ui/v1/accounts/
    labelKey: accountName
    valueKey: accountId
```

#### x-ui-disable-tooltip
Tooltip text when dynamic enum dropdown is disabled.

```yaml
container_port:
  type: integer
  x-ui-dynamic-enum: spec.containers.*.ports.*.port
  x-ui-disable-tooltip: No ports configured
```

#### x-ui-mask
Masks/hides sensitive field content.

```yaml
password:
  type: string
  title: Password
  x-ui-mask: true
```

#### x-ui-ignore-parentkey
Flattens UI hierarchy by hiding parent key.

```yaml
configuration:
  type: object
  title: Configuration
  x-ui-ignore-parentkey: true
  x-ui-yaml-editor: true
```

#### x-ui-title-replace
Replaces the title shown in UI.

```yaml
manifests:
  type: object
  title: Manifests
  x-ui-title-replace: manifest
```

#### x-ui-allow-blueprint-merge
Enables blueprint inheritance and merging.

```yaml
spec:
  type: object
  x-ui-allow-blueprint-merge: true
  properties:
    configuration:
      type: object
```

#### x-ui-allow-title-edit
Allows the user to edit the title/key of a dynamic entry (e.g., in patternProperties objects).

```yaml
env_vars:
  type: object
  title: Environment Variables
  x-ui-allow-title-edit: true
  patternProperties:
    ^[a-zA-Z_][a-zA-Z0-9_]*$:
      type: string
```

#### x-ui-select-max / x-ui-select-min
Constrains the number of selections allowed in a multi-select field.

```yaml
target_regions:
  type: array
  title: Target Regions
  x-ui-multi-select: true
  x-ui-select-min: 1
  x-ui-select-max: 3
  items:
    type: string
    enum:
      - us-east-1
      - us-west-2
      - eu-west-1
      - ap-southeast-1
```

---

## 6. Inputs and Outputs

### 6.1 Input Definition

```yaml
inputs:
  cloud_account:
    type: "@facets/aws_cloud_account"
    displayName: Cloud Account
    description: The AWS Cloud Account where resources will be created
    optional: false
    default:
      resource_type: cloud_account
      resource_name: default
    providers:
      - aws

  network_details:
    type: "@facets/aws-vpc-details"
    displayName: Network
    optional: false
    default:
      resource_type: network
      resource_name: default

  kubernetes_details:
    type: "@facets/eks"
    displayName: Kubernetes Cluster
    optional: true
    providers:
      - kubernetes # Must specify provider
      - helm # Check for the helm resource usage in the main.tf and if it exists, then we must add it as a provider here.
```

### 6.2 Output Definition

**Simple output:**
```yaml
outputs:
  default:
    type: "@facets/postgres"
    title: PostgreSQL Database Output
```

**Output with providers:**
```yaml
outputs:
  default:
    type: "@facets/eks"
    title: EKS Cluster Attributes

  attributes:
    type: "@facets/kubernetes-details"
    title: Kubernetes Cluster Output
    providers:
      kubernetes:
        source: hashicorp/kubernetes
        version: 2.38.0
        attributes:
          host: cluster_endpoint
          cluster_ca_certificate: cluster_ca_certificate
          exec:
            api_version: kubernetes_provider_exec.api_version
            command: kubernetes_provider_exec.command
            args: kubernetes_provider_exec.args
      helm:
        source: hashicorp/helm
        version: 2.17.0
        attributes:
          kubernetes:
            host: cluster_endpoint
            cluster_ca_certificate: cluster_ca_certificate
```

**IMPORTANT**: Modules exposing providers must follow the dual-output pattern ("Provider-Exposing Module Output Convention"):
- `default`: Cloud-specific type, NO providers
- `attributes`: Generic type, WITH providers

---

## 7. Sample Configuration

### 7.1 Sample Structure

```yaml
sample:
  kind: postgres
  flavor: aws-rds
  version: "1.0"
  disabled: false
  spec:
    version_config:
      engine_version: "16.12"
      database_name: postgres
    sizing:
      instance_class: db.t3.small
      allocated_storage: 100
      read_replica_count: 0
    security_config:
      deletion_protection: true
    restore_config:
      restore_from_backup: false
    imports: {}
```

### 7.2 Sample Validation Rules

**IMP**: All required fields from spec schema must exist in sample, even with empty values.

**IMP**: Sample values must be valid enum options.

**IMP**: Use `{}` for objects, `[]` for arrays, never `null`.

```yaml
# BAD
sample:
  spec:
    values: null
    tolerations: []  # Wrong if schema says type: object

# GOOD
sample:
  spec:
    values: {}
    tolerations: {}  # Correct for type: object with patternProperties
```

---

## 8. Validation Rules

### 8.1 Critical Rules from rules.md

**IMP**: Every facets.yaml MUST include intentDetails.

**IMP**: All variables must have complete schemas, never `type: any`.

**IMP**: No regex lookahead/lookbehind in patterns.

**IMP**: No duplicate enum values.

**IMP**: Place `required` array inside patternProperties definition.

**IMP**: No unsupported `metadata:` in facets.yaml.

### 8.2 Checking Validation

Always validate modules with:
```bash
raptor create iac-module -f <module-path> --dry-run
```

If security scan fails, report findings but can retry with:
```bash
raptor create iac-module -f <module-path> --dry-run --skip-security-scan
```

**NEVER** use `--skip-validation` flag.

---

## 9. Common Patterns

### 9.1 Grouped Configuration Sections

```yaml
spec:
  type: object
  x-ui-order:
    - basic_config
    - advanced_config
    - security_config

  properties:
    basic_config:
      type: object
      title: Basic Configuration
      x-ui-order:
        - name
        - version
      properties:
        name:
          type: string
          title: Name
        version:
          type: string
          title: Version
      required:
        - name
        - version
```

### 9.2 Conditional Fields with Validation

```yaml
enable_ssl:
  type: boolean
  title: Enable SSL
  default: true

ssl_certificate:
  type: string
  title: SSL Certificate ARN
  x-ui-visible-if:
    field: spec.enable_ssl
    values: [true]
  x-ui-placeholder: arn:aws:acm:region:account:certificate/id
```

### 9.3 Dynamic Dropdowns with Filtering

```yaml
config_map_name:
  type: string
  title: Config Map
  x-ui-api-source:
    endpoint: /cc-ui/v1/dropdown/stack/{{stackName}}/resources-info
    method: GET
    params:
      includeContent: false
    labelKey: resourceName
    valueKey: resourceName
    valueTemplate: ${config_map.{{value}}.out.attributes.name}
    filterConditions:
      - field: resourceType
        value: config_map
  x-ui-typeable: true
```

### 9.4 Restore/Import Pattern

```yaml
restore_config:
  type: object
  title: Restore Operations
  x-ui-overrides-only: true
  properties:
    restore_from_backup:
      type: boolean
      title: Restore from Backup
      default: false

    source_db_instance_identifier:
      type: string
      title: Source DB Instance Identifier
      x-ui-visible-if:
        field: spec.restore_config.restore_from_backup
        values: [true]
```

### 9.5 Resource Size/Limits Pattern

```yaml
resources:
  type: object
  title: Resource Limits
  x-ui-order:
    - cpu_limit
    - memory_limit
    - cpu_request
    - memory_request
  properties:
    cpu_limit:
      type: string
      title: CPU Limit
      pattern: ^([0-9]+m|[0-9]+(\.[0-9]+)?)$
      default: "1"
      x-ui-placeholder: "1.0 or 1000m"

    cpu_request:
      type: string
      title: CPU Request
      pattern: ^([0-9]+m|[0-9]+(\.[0-9]+)?)$
      x-ui-compare:
        field: spec.resources.cpu_limit
        comparator: <=
        x-ui-error-message: CPU request cannot exceed CPU limit
      x-ui-placeholder: "0.5 or 500m"

    memory_limit:
      type: string
      title: Memory Limit
      pattern: ^[0-9]+(Mi|Gi)$
      default: "1Gi"
      x-ui-placeholder: "1Gi or 1024Mi"

    memory_request:
      type: string
      title: Memory Request
      pattern: ^[0-9]+(Mi|Gi)$
      x-ui-compare:
        field: spec.resources.memory_limit
        comparator: <=
        x-ui-error-message: Memory request cannot exceed memory limit
      x-ui-placeholder: "512Mi or 1Gi"
```

---

## 10. Quick Reference

### 10.1 Required Fields Checklist

- [ ] `intent`, `flavor`, `version`, `description`
- [ ] `intentDetails` (type, description, displayName, iconUrl)
- [ ] `clouds` array
- [ ] `spec` with complete schema (no `type: any`)
- [ ] `sample` matching spec schema
- [ ] `inputs` with proper output types
- [ ] `outputs` with proper output types

### 10.2 x-ui Tags Quick Reference

| Tag | Purpose | Example |
|-----|---------|---------|
| `x-ui-order` | Control field display order | `x-ui-order: [field1, field2]` |
| `x-ui-visible-if` | Conditional field visibility | `field: spec.type, values: [app]` |
| `x-ui-overrides-only` | Environment-level only | `x-ui-overrides-only: true` |
| `x-ui-override-disable` | Blueprint-level only | `x-ui-override-disable: true` |
| `x-ui-toggle` | Collapsible section | `x-ui-toggle: true` |
| `x-ui-placeholder` | Input field placeholder | `x-ui-placeholder: example-value` |
| `x-ui-error-message` | Custom validation error | `x-ui-error-message: "Error text"` |
| `x-ui-dynamic-enum` | Dropdown from spec path | `x-ui-dynamic-enum: spec.ports.*.port` |
| `x-ui-api-source` | Dropdown from API | See detailed example above |
| `x-ui-output-type` | Filter by output type | `x-ui-output-type: iam_policy` |
| `x-ui-secret-ref` | Secret reference field | `x-ui-secret-ref: true` |
| `x-ui-variable-ref` | Variable reference field | `x-ui-variable-ref: true` |
| `x-ui-typeable` | Allow manual typing | `x-ui-typeable: true` |
| `x-ui-compare` | Compare with another field | `field: x, comparator: <=` |
| `x-ui-unique` | Enforce unique array values | `x-ui-unique: true` |
| `x-ui-yaml-editor` | YAML editor for objects | `x-ui-yaml-editor: true` |
| `x-ui-textarea` | Multiline text input | `x-ui-textarea: true` |
| `x-ui-skip` | Hide field from UI | `x-ui-skip: true` |
| `x-ui-no-sort` | Preserve enum order | `x-ui-no-sort: true` |
| `x-ui-mask` | Mask sensitive content | `x-ui-mask: true` |
| `x-ui-command` | Command array handling | `x-ui-command: true` |
| `x-ui-disable-tooltip` | Tooltip when disabled | `x-ui-disable-tooltip: "No ports"` |
| `x-ui-show-label-selected` | Show label not value | `x-ui-show-label-selected: true` |
| `x-ui-lookup-regex` | Extract values with regex | `x-ui-lookup-regex: pattern` |
| `x-ui-ignore-parentkey` | Flatten UI hierarchy | `x-ui-ignore-parentkey: true` |
| `x-ui-title-replace` | Override field title | `x-ui-title-replace: "New Title"` |
| `x-ui-allow-blueprint-merge` | Enable blueprint merge | `x-ui-allow-blueprint-merge: true` |
| `x-ui-immutable` | Read-only after creation | `x-ui-immutable: true` |
| `x-ui-critical` | Permission-gated field | `x-ui-critical: true` |
| `x-ui-artifact` | Artifact reference picker | `x-ui-artifact: true` |
| `x-ui-multi-select` | Multi-select dropdown | `x-ui-multi-select: true` |
| `x-ui-select-max` / `x-ui-select-min` | Limit selection count | `x-ui-select-min: 1, x-ui-select-max: 3` |
| `x-ui-radio` | Radio button rendering | `x-ui-radio: true` |
| `x-ui-editor` / `x-ui-editor-language` | Monaco code editor | `x-ui-editor: true, x-ui-editor-language: json` |
| `x-ui-allow-title-edit` | Editable dynamic key title | `x-ui-allow-title-edit: true` |
| `x-ui-output` | Output reference picker | `x-ui-output: true` |
| `x-ui-array-input-validation` | Array item validation | `x-ui-array-input-validation: {pattern: ..., errorMessage: ...}` |
| `x-ui-unique-pattern-error-message` | Custom uniqueness error | `x-ui-unique-pattern-error-message: "Duplicate"` |

### 10.3 JSON Schema Validation Quick Reference

| Validation | Type | Example |
|------------|------|---------|
| `pattern` | string | `pattern: ^[a-zA-Z0-9_-]+$` |
| `minLength` / `maxLength` | string | `minLength: 1, maxLength: 63` |
| `minimum` / `maximum` | number | `minimum: 0, maximum: 100` |
| `enum` | any | `enum: [value1, value2]` |
| `default` | any | `default: "default-value"` |
| `required` | object | `required: [field1, field2]` |

### 10.4 Common Validation Patterns

```yaml
# DNS-compatible name
pattern: ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$

# Database name
pattern: ^[a-zA-Z][a-zA-Z0-9_]*$
minLength: 1
maxLength: 63

# Port number
type: integer
minimum: 1
maximum: 65535

# CPU (cores or millicores)
pattern: ^([0-9]+m|[0-9]+(\.[0-9]+)?)$

# Memory (Mi or Gi)
pattern: ^[0-9]+(Mi|Gi)$

# ARN
pattern: ^arn:aws:[a-z0-9-]+:[a-z0-9-]*:[0-9]{12}:.+$

# Semantic version
pattern: ^\d+\.\d+(\.\d+)?$
```

---

## When to Use This Skill

This skill auto-loads when:
- Working with any `facets.yaml` file
- Creating a new Facets module
- Modifying module schemas
- Designing spec configurations
- Adding UI customizations

**Always check:** Before completing facets.yaml work, validate against rules.md using:
```bash
raptor create iac-module -f <module-path> --dry-run
```

---
