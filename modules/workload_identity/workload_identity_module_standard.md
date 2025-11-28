# Workload Identity Module Standards

These instructions supplement the default Facets module generation guidelines for this repository.

## Repository Scope

This repository contains workload identity modules for Azure and GCP that enable Kubernetes workloads to authenticate with cloud services using service accounts instead of static credentials.

## Design Philosophy

### Simplicity Over Flexibility
- Provide secure cloud IAM integration with minimal configuration
- Do NOT expose every possible IAM configuration option
- Use secure, production-ready defaults that don't require configuration
- Abstract away complex IAM role/identity federation setups
- Focus on developer experience - make cloud authentication easy

### Security-First Defaults
- Always use workload identity over static credentials
- Follow principle of least privilege for IAM permissions
- Enable audit logging where applicable
- Do NOT expose or store service account keys
- Use short-lived tokens and assume role patterns

### Technology-Familiar Field Names
- Use field names familiar to Kubernetes and cloud IAM users
- Do NOT invent new abstractions for standard cloud concepts
- Make modules configurable by developers who are not IAM experts

## Module Conventions

### Naming Standards
- **Intent**: Use `workload_identity` for all cloud providers
- **Flavors**: Cloud-specific names (e.g., `azure`, `gcp`)
- Note: AWS uses IRSA (IAM Roles for Service Accounts) which is typically embedded in the service module

- **All outputs and inputs MUST use `@facets/` namespace prefix**
- **STRICTLY FORBIDDEN: Using any output types that do NOT start with `@facets/`**

## Core Functionality Requirements

Every module MUST provide support for:

1. **Service Account Creation**
   - Kubernetes service account creation
   - Namespace specification
   - Annotations for cloud IAM binding

2. **IAM Integration**
   - Cloud identity federation configuration
   - IAM role/service account binding
   - Permission scope management

3. **Policy Attachment**
   - Attach cloud IAM policies/roles
   - Support for custom and managed policies
   - Minimal required permissions by default

4. **Kubernetes Integration**
   - Automatic service account annotation
   - Pod identity webhook configuration (where applicable)
   - OIDC provider integration

## Module Structure

### Required Files
```
workload_identity/
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
- **Default output**: Use cloud-specific workload identity types:
  - `@facets/azure_workload_identity` (Azure)
  - `@facets/gcp_workload_identity` (GCP)

### Standard Output Structure

**Azure Pattern:**
```yaml
outputs:
  default:
    type: '@facets/azure_workload_identity'
    title: Azure Workload Identity Output
    description: Kubernetes service account with Azure AD workload identity binding
```

**GCP Pattern:**
```yaml
outputs:
  default:
    type: '@facets/gcp_workload_identity'
    title: GCP Workload Identity Output
    description: Kubernetes service account with GCP workload identity binding
```

## Spec Structure

All modules MUST organize their `spec.properties` with minimal required fields:

### Common Fields
- `namespace`: Kubernetes namespace for service account
- `service_account_name`: Name of the Kubernetes service account
- `iam_policies` or `iam_roles`: Cloud IAM permissions to attach
- `labels` or `tags`: Resource labeling

### Cloud-Specific Spec Examples

**Azure Workload Identity Pattern:**
```yaml
spec:
  type: object
  properties:
    service_account_name:
      type: string
      title: Service Account Name
      description: Name of the Kubernetes service account
      pattern: ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$
      x-ui-placeholder: my-service-account

    namespace:
      type: string
      title: Namespace
      description: Kubernetes namespace where service account will be created
      default: default

    user_assigned_identity_name:
      type: string
      title: User Assigned Identity Name
      description: Name for the Azure User Assigned Managed Identity
      pattern: ^[a-zA-Z0-9][-a-zA-Z0-9_]*[a-zA-Z0-9]$

    federated_identity_name:
      type: string
      title: Federated Identity Credential Name
      description: Name for the federated identity credential

    azure_role_assignments:
      type: array
      title: Azure Role Assignments
      description: Azure RBAC role assignments for the managed identity
      items:
        type: object
        properties:
          role:
            type: string
            title: Role
            description: Azure built-in or custom role name
          scope:
            type: string
            title: Scope
            description: Resource scope for role assignment (subscription, resource group, resource)

    tags:
      type: object
      title: Tags
      x-ui-yaml-editor: true

  required:
    - service_account_name
    - namespace
    - user_assigned_identity_name
```

**GCP Workload Identity Pattern:**
```yaml
spec:
  type: object
  properties:
    service_account_name:
      type: string
      title: Kubernetes Service Account Name
      description: Name of the Kubernetes service account
      pattern: ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$

    namespace:
      type: string
      title: Namespace
      description: Kubernetes namespace where service account will be created
      default: default

    gcp_service_account_name:
      type: string
      title: GCP Service Account Name
      description: Name for the GCP service account (will be created if it doesn't exist)
      pattern: ^[a-z]([-a-z0-9]*[a-z0-9])?$

    gcp_service_account_description:
      type: string
      title: GCP Service Account Description
      description: Description for the GCP service account
      default: ""

    iam_roles:
      type: array
      title: IAM Roles
      description: GCP IAM roles to grant to the service account
      items:
        type: string
        title: Role
        description: GCP IAM role (e.g., roles/storage.objectViewer)
      default: []

    project_roles:
      type: array
      title: Project-Level IAM Roles
      description: IAM roles to grant at project level
      items:
        type: object
        properties:
          role:
            type: string
            title: Role
          project:
            type: string
            title: Project ID
            description: GCP project ID (optional, defaults to current project)

    labels:
      type: object
      title: Labels
      x-ui-yaml-editor: true

  required:
    - service_account_name
    - namespace
    - gcp_service_account_name
```

### Allowed Configuration Fields

**These fields ARE acceptable:**
- Service account naming and namespace
- Cloud IAM role/policy assignments
- Resource labeling/tagging
- Federated identity configuration
- Scope definitions for permissions

**These fields are FORBIDDEN:**
- Static credentials or service account keys
- Custom OIDC provider configuration (should be cluster-level)
- Low-level IAM policy JSON
- Network or security configurations
- Cluster-wide IAM configurations

## Required Input Types

All workload identity modules MUST consume:

1. **Cloud Account** (MANDATORY):
   - `@facets/azure_cloud_account` (Azure)
   - `@facets/gcp_cloud_account` (GCP)
   - Must specify provider configurations

2. **Kubernetes Cluster Details** (MANDATORY):
   - `@facets/kubernetes-details` or cloud-specific types
   - `@facets/azure_aks` (Azure)
   - `@facets/gke` (GCP)
   - Must provide kubernetes and kubernetes-alpha providers
   - Should have sensible defaults (e.g., `resource_name: default`)

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
- Keep configuration minimal and focused on IAM bindings
- Include essential fields for identity and permissions

**Input Requirements:**
- Cloud account input (MANDATORY): `@facets/{cloud}_cloud_account`
- Kubernetes cluster input (MANDATORY): `@facets/kubernetes-details` or cloud-specific
- **STRICTLY FORBIDDEN**: Using any non-`@facets/` prefixed types

**Output Types:**
- Default output: Cloud-specific workload identity type
- **CRITICAL**: ALL output types MUST start with `@facets/`

## Cloud-Specific Considerations

### Azure Workload Identity
- Uses Azure AD Pod Identity or Azure Workload Identity (newer)
- Requires User Assigned Managed Identity
- Federated identity credential for OIDC trust
- Azure RBAC role assignments
- Use `azurerm` and `azapi` providers from cloud account
- Requires cluster to have OIDC issuer enabled

### GCP Workload Identity
- Uses GCP Workload Identity Federation
- Requires GCP service account creation
- IAM policy binding between K8s SA and GCP SA
- Project-level and resource-level IAM roles
- Use `google` and `google-beta` providers from cloud account
- Requires cluster to have workload identity enabled

### AWS IRSA
- Note: AWS uses IRSA (IAM Roles for Service Accounts)
- Typically embedded in the service module rather than separate
- Uses IAM OIDC provider with EKS cluster
- IAM role with trust policy for service account
- Policy attachments for permissions

## Validation Checklist

Before completing any module:
- [ ] Outputs use `@facets/` namespace
- [ ] Default output uses cloud-specific workload identity type
- [ ] Inputs only consume `@facets/` namespaced types
- [ ] Cloud account and Kubernetes cluster inputs configured
- [ ] Kubernetes service account creation configured
- [ ] Cloud IAM identity creation configured
- [ ] Identity federation/binding properly set up
- [ ] IAM permissions properly scoped
- [ ] Security defaults follow least privilege
- [ ] Module validates successfully
- [ ] Provider configurations properly reference inputs
- [ ] No static credentials or keys exposed
- [ ] Follows cloud-specific patterns from existing modules
