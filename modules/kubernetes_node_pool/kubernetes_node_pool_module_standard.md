# Kubernetes Node Pool Module Standards

These instructions supplement the default Facets module generation guidelines for this repository.

## Repository Scope

This repository contains node pool modules for Kubernetes clusters across different cloud providers (AWS, Azure, GCP). Each module represents a cloud-specific node pool implementation for managing compute capacity.

## Design Philosophy

### Simplicity Over Flexibility
- Provide common node pool functionalities with sensible defaults
- Do NOT expose every possible configuration option
- Use secure, production-ready defaults that don't require configuration
- Users can fork the repository for custom configurations
- **Prefer cloud-managed features** (auto-upgrade, auto-scaling) over manual configuration

### Technology-Familiar Field Names
- Use field names familiar to Kubernetes and cloud provider users
- Do NOT invent new abstractions or terms
- Make modules configurable by developers who are not cloud experts
- Abstract away low-level infrastructure details

### Security-First Defaults
- Always configure secure, production-ready defaults (hardcoded, not configurable)
- Enable automatic security updates where available
- Follow principle of least privilege for node IAM roles
- Use private node configurations where possible
- Enable node auto-upgrade by default

## Module Conventions

### Naming Standards
- **Intent**: Use `kubernetes_node_pool` for all cloud providers
- **Flavors**: Cloud-specific names (e.g., `aws`, `azure`, `gcp`, `gcp_node_fleet`)
- **Name Length Limits**: Ensure generated resource names comply with cloud provider and Kubernetes naming constraints (63 characters max)

- **All outputs and inputs MUST use `@facets/` namespace prefix**
- **STRICTLY FORBIDDEN: Using any output types that do NOT start with `@facets/`**

## Core Functionality Requirements

Every module MUST provide support for:

1. **Node Configuration**
   - Instance type/size selection
   - Node count (min, max, desired)
   - Disk size and type
   - OS and AMI/image selection (with sensible defaults)

2. **Auto-Scaling**
   - Cluster autoscaler integration
   - Min/max node count configuration
   - Scale-down behavior

3. **Auto-Upgrade**
   - **PREFER auto-upgrade enabled by default**
   - Let cloud providers manage node OS and Kubernetes version updates
   - Maintenance window configuration (where applicable)

4. **Node Labels and Taints**
   - Custom Kubernetes labels for pod scheduling
   - Taints for workload isolation
   - Node selector support

5. **Networking**
   - Pod networking configuration (inherit from cluster)
   - Security group assignments
   - Subnet/network placement

6. **IAM Integration**
   - Node IAM role/identity configuration
   - Cloud-specific workload identity support
   - Minimal required permissions

## Module Structure

### Required Files
```
kubernetes_node_pool/
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
- **Default output**: Use cloud-specific names for node pool outputs:
  - `@facets/aws_karpenter_nodepool` or `@facets/aws_eks_nodegroup` (AWS)
  - `@facets/azure_aks_nodepool` (Azure)
  - `@facets/gcp_nodepool` (GCP)

### Standard Output Structure

**AWS Pattern:**
```yaml
outputs:
  default:
    type: '@facets/aws_karpenter_nodepool'  # or @facets/aws_eks_nodegroup
    title: AWS Node Pool Output
    description: EKS node pool configuration and details
```

**Azure Pattern:**
```yaml
outputs:
  default:
    type: '@facets/azure_aks_nodepool'
    title: Azure AKS Node Pool Output
    description: AKS node pool configuration and details
```

**GCP Pattern:**
```yaml
outputs:
  default:
    type: '@facets/gcp_nodepool'
    title: GCP GKE Node Pool Output
    description: GKE node pool configuration and details
```

## Spec Structure

**IMPORTANT**: Spec structure is **cloud-specific** and should follow the patterns established by existing modules for that cloud provider. Do NOT enforce a universal structure across all clouds.

### Common Grouping Patterns

All modules MUST organize their `spec.properties` using **GROUPED OBJECTS** where applicable:

**Common Groups (not all required):**
- Node configuration (instance type, count, disk)
- Auto-scaling settings
- Auto-upgrade settings
- Node labels and taints
- Tags/labels

### Cloud-Specific Spec Examples

**AWS Pattern (Karpenter):**
```yaml
spec:
  type: object
  properties:
    node_configuration:
      type: object
      title: Node Configuration
      properties:
        instance_types:
          type: array
          title: Instance Types
          items:
            type: string
          default: [t3.medium]

        capacity_type:
          type: string
          title: Capacity Type
          enum: [on-demand, spot]
          default: on-demand

        disk_size:
          type: integer
          title: Disk Size (GB)
          default: 50

    scaling:
      type: object
      title: Scaling Configuration
      properties:
        min_nodes:
          type: integer
          default: 1
        max_nodes:
          type: integer
          default: 10

    node_labels:
      type: object
      title: Node Labels
      x-ui-yaml-editor: true

    node_taints:
      type: array
      title: Node Taints
      items:
        type: object
        properties:
          key: {type: string}
          value: {type: string}
          effect: {enum: [NoSchedule, PreferNoSchedule, NoExecute]}

    tags:
      type: object
      x-ui-yaml-editor: true
```

**Azure Pattern (AKS):**
```yaml
spec:
  type: object
  properties:
    node_configuration:
      type: object
      properties:
        vm_size:
          type: string
          title: VM Size
          default: Standard_D2_v4

        node_count:
          type: integer
          title: Node Count
          default: 3

        os_disk_size_gb:
          type: integer
          title: OS Disk Size (GB)
          default: 50

        os_type:
          type: string
          enum: [Linux, Windows]
          default: Linux

    auto_scaling:
      type: object
      properties:
        enabled:
          type: boolean
          default: true
        min_count:
          type: integer
          default: 1
        max_count:
          type: integer
          default: 10

    auto_upgrade:
      type: object
      properties:
        enabled:
          type: boolean
          default: true
        channel:
          type: string
          enum: [patch, stable, rapid]
          default: stable

    node_labels:
      type: object
      x-ui-yaml-editor: true

    node_taints:
      type: array

    tags:
      type: object
      x-ui-yaml-editor: true
```

**GCP Pattern (GKE):**
```yaml
spec:
  type: object
  properties:
    node_configuration:
      type: object
      properties:
        machine_type:
          type: string
          title: Machine Type
          default: e2-medium

        disk_size_gb:
          type: integer
          title: Disk Size (GB)
          default: 50

        disk_type:
          type: string
          enum: [pd-standard, pd-ssd, pd-balanced]
          default: pd-balanced

        preemptible:
          type: boolean
          title: Use Preemptible Nodes
          default: false

    autoscaling:
      type: object
      properties:
        enabled:
          type: boolean
          default: true
        min_node_count:
          type: integer
          default: 1
        max_node_count:
          type: integer
          default: 10

    management:
      type: object
      properties:
        auto_upgrade:
          type: boolean
          default: true
        auto_repair:
          type: boolean
          default: true

    node_labels:
      type: object
      x-ui-yaml-editor: true

    node_taints:
      type: array

    labels:
      type: object
      x-ui-yaml-editor: true
```

### Allowed Configuration Fields

**These fields ARE acceptable:**
- Instance/VM/machine type selection
- Node count and auto-scaling parameters
- Auto-upgrade and auto-repair settings
- Disk size and type
- Node labels and taints
- Resource tags/labels
- Capacity type (on-demand vs spot/preemptible)

**These fields are FORBIDDEN:**
- Low-level networking (subnet IDs, security groups)
- Detailed IAM role configurations
- Custom AMI/image IDs (use defaults)
- SSH key configurations
- User data scripts

## Required Input Types

All node pool modules MUST consume:

1. **Cloud Account** (MANDATORY):
   - `@facets/aws_cloud_account` (AWS)
   - `@facets/azure_cloud_account` (Azure)
   - `@facets/gcp_cloud_account` (GCP)
   - Must specify provider configurations

2. **Kubernetes Cluster Details** (MANDATORY):
   - `@facets/kubernetes-details` or cloud-specific types
   - Should have sensible defaults (e.g., `resource_name: default`)

3. **Network Details** (Cloud-Specific):
   - `@facets/aws-vpc-details` (AWS)
   - `@facets/azure-network-details` (Azure)
   - `@facets/gcp-network-details` (GCP)
   - Optional or required depending on cloud provider

## Development Workflow

### Pre-Planning Requirements
**BEFORE presenting any module plan:**
1. **Fetch existing output types** using appropriate tools
2. **IGNORE any output types that do NOT start with `@facets/`**
3. **CRITICAL: NEVER register output types that you need as inputs**
4. **Determine new output types** this module will create
5. **MANDATORY: Get explicit user approval** for ANY new output types
6. **Verify cloud-specific patterns** from existing modules
7. **Identify ALL required provider inputs**

### Required Plan Elements

**Spec Structure:**
- Follow cloud-specific patterns from existing modules
- Use GROUPED OBJECTS, NOT flat fields
- Include essential configuration (scaling, upgrade, labels)

**Input Requirements:**
- Cloud account input (MANDATORY): `@facets/{cloud}_cloud_account`
- Kubernetes cluster input (MANDATORY): `@facets/kubernetes-details` or cloud-specific
- **STRICTLY FORBIDDEN**: Using any non-`@facets/` prefixed types

**Output Types:**
- Default output: Cloud-specific node pool type
- **CRITICAL**: ALL output types MUST start with `@facets/`

## Cloud-Specific Considerations

### AWS (EKS)
- Support for both EKS Managed Node Groups and Karpenter
- Karpenter for advanced auto-scaling and bin-packing
- Spot instance support
- Launch template configuration
- Use `aws` provider from cloud account

### Azure (AKS)
- System node pools vs user node pools
- Virtual Machine Scale Sets (VMSS)
- Availability zone support
- Windows and Linux node pools
- Use `azurerm` provider from cloud account

### GCP (GKE)
- Node pool vs node auto-provisioning
- Workload identity support
- Shielded nodes enabled by default
- Regional vs zonal node pools
- Use `google` provider from cloud account

## Validation Checklist

Before completing any module:
- [ ] Generated resource names comply with 63 character limits
- [ ] Outputs use `@facets/` namespace
- [ ] Default output uses cloud-specific node pool type
- [ ] Inputs only consume `@facets/` namespaced types
- [ ] Cloud account and cluster inputs configured
- [ ] Auto-upgrade enabled by default
- [ ] Auto-scaling configuration included
- [ ] Security defaults hardcoded
- [ ] Spec uses GROUPED OBJECTS structure (where applicable)
- [ ] Module validates successfully
- [ ] Provider configurations properly reference inputs
- [ ] Follows cloud-specific patterns from existing modules
