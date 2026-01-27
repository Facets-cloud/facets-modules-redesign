# Cluster Module Standards

These instructions supplement the default Facets module generation guidelines for this repository.

## Repository Scope

This repository contains modules for Kubernetes clusters across different cloud providers (AWS EKS, Azure AKS, GCP GKE). Each module represents a cloud-specific Kubernetes cluster implementation.

## Design Philosophy

### Simplicity Over Flexibility
- Provide common functionalities with sensible defaults
- Do NOT expose every possible configuration option
- Use secure, production-ready defaults that don't require configuration
- Users can fork the repository for custom configurations
- **Prefer cloud-managed features** (auto-upgrade, auto-scaling) over manual configuration

### Technology-Familiar Field Names
- Use field names familiar to Kubernetes and cloud provider users
- Do NOT invent new abstractions or terms
- Make modules configurable by developers who are not cloud experts
- Do NOT expose low-level cloud details (VPCs, subnets, security groups, IAM roles)
- Generate necessary infrastructure components within the module
- **ALLOW essential platform configuration** - logging, auto-upgrade settings, and cluster add-ons are acceptable when they provide value to developers

### Security-First Defaults
- Always configure secure, production-ready defaults (hardcoded, not configurable)
- Enable encryption at rest and in transit automatically
- Configure RBAC and Pod Security Standards automatically
- Follow principle of least privilege for access
- Enable cluster logging and audit logs automatically
- Default to public endpoints with CIDR restrictions (can be overridden)

### Auto-Upgrade Philosophy
- **PREFER auto-upgrade channels over explicit version selection**
- Let cloud providers manage Kubernetes version lifecycle
- Do NOT expose manual version selection unless there's a strong use case
- Use stable/regular upgrade channels as defaults

## Module Conventions

### Naming Standards
- **Intent**: Use `kubernetes_cluster` for all cloud providers
- **Flavors**: Cloud-specific names (e.g., `eks`, `aks`, `gke`)
- **Name Length Limits**: Ensure generated resource names comply with cloud provider and Kubernetes naming constraints (63 characters max)

- **All outputs and inputs MUST use `@facets/` namespace prefix**
- **STRICTLY FORBIDDEN: Using any output types that do NOT start with `@facets/` (e.g., `@outputs/`, `@modules/`, etc.)**

## Core Functionality Requirements

Every module MUST provide support for:

1. **Version Management**
   - **Prefer auto-upgrade channels** (stable, regular, rapid) over explicit versions
   - Let cloud providers manage version lifecycle automatically
   - If version must be exposed, support only the last 3 minor versions
   - **MANDATORY: Validate options against cloud provider documentation**

2. **Node Pool Configuration** (Cloud-Specific)
   - **EKS**: May use Auto Mode (no explicit node pools required)
   - **AKS**: Requires system node pool configuration
   - **GKE**: May delegate to separate node pool module
   - Support appropriate cloud-specific configurations

3. **Authentication & Security**
   - Secure credential management
   - RBAC configuration (enabled by default)
   - Integration with cloud IAM/identity providers
   - Pod Security Standards enabled by default
   - Public/private endpoint configuration

4. **Cluster Add-ons & Extensions**
   - Cloud-specific add-ons (CSI drivers, observability, networking)
   - Pattern-based configuration (patternProperties) for extensibility
   - Enable essential add-ons by default

5. **Logging Configuration** (Essential)
   - Control plane logging must be configurable
   - Log retention settings
   - Component-specific logging (API server, audit, controller manager, etc.)

6. **Import Support** (Optional but Recommended)
   - Support importing existing clusters where applicable
   - Include import declarations in facets.yaml if implemented

## Module Structure

### Required Files
```
clusters/
  {cloud-provider}/
    {flavor}/
      1.0/
        ├── facets.yaml          # Must include @facets/ outputs
        ├── main.tf             # Core Terraform resources
        ├── variables.tf        # Must mirror facets.yaml spec structure
        ├── locals.tf           # Local computations and output_attributes
        ├── outputs.tf          # Terraform outputs
        └── README.md           # Generated documentation
```

## CRITICAL: Input Type Management Rules

**NEVER register output types that you need as inputs:**
- ALL required input types MUST already exist in the control plane
- If needed input types don't exist, STOP and clarify with the user first
- Do NOT create missing input types - they must be provided by other modules

## Output Types and Structure

### MANDATORY User Approval for New Output Types
- Get explicit user confirmation before creating ANY new output type
- There is NO blanket approval for output type creation
- Present the output type structure and get approval before proceeding

### Output Naming Convention
- **Default output**: MUST use `@facets/kubernetes-details` for cross-cloud compatibility
  - This standardized output includes Kubernetes, Helm, and Kubernetes-alpha provider configurations
- **Attributes output**: Use cloud-specific names (e.g., `@facets/eks`, `@facets/azure_aks`, `@facets/gke`)
  - Contains cloud-specific attributes and optionally provider configurations

### Standard Output Structure

**All cluster modules MUST use `@facets/kubernetes-details` as default output:**

```yaml
outputs:
  default:
    type: '@facets/kubernetes-details'
    title: Kubernetes Cluster Output
    providers:
      kubernetes:
        source: hashicorp/kubernetes
        version: 2.38.0
        attributes:
          host: attributes.cluster_endpoint
          cluster_ca_certificate: attributes.cluster_ca_certificate
          exec:  # or client_certificate/client_key for Azure
            api_version: attributes.kubernetes_provider_exec.api_version
            command: attributes.kubernetes_provider_exec.command
            args: attributes.kubernetes_provider_exec.args
      helm:
        source: hashicorp/helm
        version: 3.0.2
        attributes:
          kubernetes:
            host: attributes.cluster_endpoint
            # ... similar structure
      kubernetes-alpha:
        source: hashicorp/kubernetes-alpha
        version: 0.6.0
        attributes:
          host: attributes.cluster_endpoint
          # ... similar structure

  attributes:
    type: '@facets/{cloud-specific-type}'  # e.g., @facets/eks, @facets/azure_aks, @facets/gke
    title: Cloud-Specific Cluster Attributes
    description: Additional cloud-specific cluster attributes
    providers:  # Optional - include if needed for cloud-specific tooling
      # ... cloud-specific provider configs
```

## Spec Structure

**IMPORTANT**: Spec structure is **cloud-specific** and should follow the patterns established by existing modules for that cloud provider. Do NOT enforce a universal structure across all clouds.

### Common Grouping Patterns

All modules MUST organize their `spec.properties` using **GROUPED OBJECTS**, not flat fields:

**Common Groups (not all required):**
- `cluster`: Basic cluster configuration (endpoint access, SKU tier, etc.)
- `auto_upgrade_settings` or `auto_upgrade`: Version and upgrade management
- `node_pools`: Node pool configuration (structure varies by cloud)
- `cluster_addons` or `enabled_addons`: Add-on configuration
- `logging_components`: Logging configuration
- `tags`: Resource tagging

### Cloud-Specific Spec Examples

**AWS EKS Pattern:**
```yaml
spec:
  properties:
    cluster:
      type: object
      title: "Cluster"
      properties:
        cluster_endpoint_public_access:
          type: boolean
          title: "Cluster Endpoint Public Access"
          default: true

        cluster_endpoint_public_access_cidrs:
          type: array
          title: "Cluster Endpoint Public Access CIDRs"
          default: ["0.0.0.0/0"]

        cloudwatch:
          type: object
          title: "CloudWatch"
          properties:
            log_group_retention_in_days:
              type: number
              default: 90

            enabled_log_types:
              type: array
              title: "Enabled Log Types"
              default: ["api", "audit", "authenticator"]

        cluster_addons:
          type: object
          title: "EKS Cluster Addons"
          x-ui-toggle: true
          patternProperties:
            .*:
              type: object
              properties:
                name:
                  type: string
                  enum: ["aws-efs-csi-driver", "metrics-server", ...]
                enabled:
                  type: boolean
                  default: true
                configuration_values:
                  type: object
                  default: {}

    tags:
      type: object
      x-ui-yaml-editor: true
```

**Azure AKS Pattern:**
```yaml
spec:
  properties:
    cluster:
      type: object
      title: "Cluster"
      properties:
        cluster_endpoint_public_access_cidrs:
          type: array
          default: ["0.0.0.0/0"]

        sku_tier:
          type: string
          enum: ["Free", "Standard"]
          default: "Free"

    auto_upgrade_settings:
      type: object
      title: "Auto-Upgrade Settings"
      properties:
        automatic_channel_upgrade:
          type: string
          enum: ["rapid", "regular", "stable", "patch", "node-image"]
          default: "stable"

        max_surge:
          type: string
          default: "1"

        maintenance_window:
          type: object
          properties:
            is_enabled:
              type: boolean
              default: true
            frequency:
              type: string
              enum: ["Daily", "Weekly", "AbsoluteMonthly", "RelativeMonthly"]
              default: "Weekly"
            # ... additional maintenance window settings

    node_pools:
      type: object
      title: "Node Pools"
      properties:
        system_np:
          type: object
          title: "System Node Pool"
          properties:
            enabled:
              type: boolean
              default: true
              readOnly: true
            node_count:
              type: integer
              default: 1
            instance_type:
              type: string
              default: "Standard_D2_v4"
            # ... additional node pool settings

    tags:
      type: object
      x-ui-yaml-editor: true
```

**GCP GKE Pattern:**
```yaml
spec:
  properties:
    auto_upgrade:
      type: boolean
      title: "Enable Auto-Upgrade"
      default: true

    whitelisted_cidrs:
      type: array
      title: "Whitelisted CIDRs"
      default: ["0.0.0.0/0"]

    logging_components:
      type: object
      title: "GKE Logging Components"
      x-ui-toggle: true
      patternProperties:
        .*:
          type: object
          properties:
            name:
              type: string
              enum: ["SYSTEM_COMPONENTS", "WORKLOADS", "APISERVER", ...]
            enabled:
              type: boolean
              default: true
```

### Allowed Configuration Fields

**These fields ARE acceptable** when they provide developer value:
- Logging component selection and log retention
- Auto-upgrade channel configuration
- Maintenance window settings (for predictable upgrades)
- Cluster add-ons and extensions
- Public endpoint CIDR restrictions
- Essential node pool configuration
- Resource tagging

**These fields are still FORBIDDEN:**
- Low-level networking (VPC IDs, subnet IDs, route table configs)
- Detailed IAM role/policy configurations
- Security group rules
- Monitoring/alerting threshold configurations
- Backup schedules and policies

## Required Input Types

All cluster modules MUST consume:

1. **Cloud Account** (MANDATORY):
   - `@facets/aws_cloud_account` (EKS)
   - `@facets/azure_cloud_account` (AKS)
   - `@facets/gcp_cloud_account` (GKE)
   - Must specify provider configurations

2. **Network Details** (MANDATORY):
   - `@facets/aws-vpc-details` (EKS)
   - `@facets/azure-network-details` (AKS)
   - `@facets/gcp-network-details` (GKE)
   - Should have sensible defaults (e.g., `resource_name: default`)

## Development Workflow

When using `generate_module_with_user_confirmation` to present module plans, ensure the following requirements are met:

### Pre-Planning Requirements
**BEFORE presenting any module plan:**
1. **Fetch existing output types** using appropriate tools to understand what `@facets/` types are already available for inputs
2. **IGNORE any output types that do NOT start with `@facets/`**
3. **CRITICAL: NEVER register output types that you need as inputs** - ALL required input types MUST already exist
4. **Determine new output types** this module will create (default + attributes outputs)
5. **MANDATORY: Get explicit user approval** for ANY new output types before proceeding
6. **Verify cloud-specific patterns** by examining existing modules for that cloud provider
7. **Identify ALL required provider inputs** (cloud account, network details)

### Required Plan Elements

**Spec Structure:**
- Follow cloud-specific patterns from existing modules
- Use GROUPED OBJECTS, NOT flat fields
- Include essential configuration (logging, add-ons, node pools where applicable)
- Use patternProperties for extensible configurations (add-ons, logging components)

**Input Requirements:**
- Cloud account input (MANDATORY): `@facets/{cloud}_cloud_account`
- Network details input (MANDATORY): `@facets/{cloud}-network-details` or `@facets/{cloud}-vpc-details`
- **STRICTLY FORBIDDEN**: Using any non-`@facets/` prefixed types

**Output Types:**
- Default output: `@facets/kubernetes-details` (REQUIRED for all clusters)
- Attributes output: `@facets/{cloud-specific-type}` (mark NEW/REUSED)
- **CRITICAL**: ALL output types MUST start with `@facets/`

## Cloud-Specific Considerations

### AWS EKS
- Support for EKS Auto Mode (no explicit node groups required)
- EKS add-ons (VPC CNI, CoreDNS, kube-proxy, CSI drivers, observability)
- CloudWatch logging with configurable retention
- IRSA (IAM Roles for Service Accounts) configured automatically
- Use `aws` provider from cloud account

### Azure AKS
- Requires system node pool configuration (cannot be disabled)
- Auto-upgrade channel configuration (stable, rapid, regular, patch, node-image)
- Maintenance window configuration for predictable upgrades
- SKU tier selection (Free, Standard)
- Use `azurerm` and `azapi` providers from cloud account

### GCP GKE
- Auto-upgrade via release channels
- Logging components configuration (SYSTEM_COMPONENTS, WORKLOADS, etc.)
- May delegate node pools to separate module (indicated in description)
- Whitelisted CIDRs for API access
- Use `google` and `google-beta` providers from cloud account

## Validation Checklist

Before completing any module:
- [ ] Generated resource names comply with 63 character limits
- [ ] Auto-upgrade configuration enabled by default (or explicit version validated)
- [ ] Outputs use `@facets/` namespace
- [ ] Default output is `@facets/kubernetes-details` with kubernetes, helm, and kubernetes-alpha providers
- [ ] Inputs only consume `@facets/` namespaced types
- [ ] Cloud account and network details inputs configured
- [ ] Security defaults hardcoded (encryption, RBAC, Pod Security Standards)
- [ ] Network components auto-generated (VPC, subnets, security groups, IAM roles)
- [ ] **Spec uses GROUPED OBJECTS structure - NOT flat fields**
- [ ] **Essential platform config included (logging, add-ons) - low-level config excluded (networking, IAM)**
- [ ] Module validates successfully with `validate_module()`
- [ ] Provider configurations properly reference cloud account input
- [ ] Follows cloud-specific patterns from existing modules
