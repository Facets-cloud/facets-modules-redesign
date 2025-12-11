# Cloud Account Module Standards

These instructions supplement the default Facets module generation guidelines for this repository.

## Repository Scope

This repository contains cloud account provider modules for AWS, Azure, and GCP. Each module configures cloud provider authentication and establishes provider configurations for downstream resources.

## Design Philosophy

### Simplicity Over Flexibility
- Provide essential cloud provider authentication with minimal configuration
- Do NOT expose low-level provider settings unless absolutely necessary
- Use secure, production-ready defaults that don't require configuration
- Focus on establishing provider configurations for other modules to consume

### Security-First Defaults
- Always use secure authentication methods (IAM roles, service principals, service accounts)
- Follow principle of least privilege
- Do NOT store or expose credentials directly
- Enable audit logging by default where applicable

## Module Conventions

### Naming Standards
- **Intent**: Use `cloud_account` for all cloud providers
- **Flavors**: Provider-specific names (e.g., `aws_provider`, `azure_provider`, `gcp_provider`)

- **All outputs MUST use `@facets/` namespace prefix**
- **STRICTLY FORBIDDEN: Using any output types that do NOT start with `@facets/`**

## Core Functionality Requirements

Every module MUST provide support for:

1. **Provider Authentication**
   - Cloud account selection via API integration
   - Region/location configuration
   - Secure credential management (assume role, service principal, service account)

2. **Provider Configuration Output**
   - Must output provider configuration block for downstream modules
   - Include all necessary authentication attributes
   - Support for multiple provider versions where applicable

3. **Account Metadata**
   - Account ID/subscription ID/project ID
   - Region/location information
   - Session naming and external ID (where applicable)

## Module Structure

### Required Files
```
cloud_account/
  {flavor}/
    1.0/
      ├── facets.yaml          # Must include @facets/ outputs
      ├── locals.tf           # Local computations and output_attributes
      ├── outputs.tf          # Terraform outputs
      ├── variables.tf        # Must mirror facets.yaml spec structure
      └── README.md           # Generated documentation
```

## Output Types and Structure

### MANDATORY User Approval for New Output Types
- Get explicit user confirmation before creating ANY new output type
- There is NO blanket approval for output type creation
- Present the output type structure and get approval before proceeding

### Output Naming Convention
- **Default output**: MUST use cloud-specific type names:
  - `@facets/aws_cloud_account` (AWS)
  - `@facets/azure_cloud_account` (Azure)
  - `@facets/gcp_cloud_account` (GCP)

### Standard Output Structure

**AWS Pattern:**
```yaml
outputs:
  default:
    type: '@facets/aws_cloud_account'
    providers:
      aws:
        source: hashicorp/aws
        version: = 6.9.0
        attributes:
          region: attributes.aws_region
          skip_region_validation: true
          assume_role:
            role_arn: attributes.aws_iam_role
            session_name: attributes.session_name
            external_id: attributes.external_id
```

**Azure Pattern:**
```yaml
outputs:
  default:
    type: '@facets/azure_cloud_account'
    providers:
      azurerm:
        source: hashicorp/azurerm
        version: ~> 4.11.0
        attributes:
          # Azure-specific provider configuration
      azapi:
        source: azure/azapi
        version: ~> 2.1.0
        attributes:
          # AzAPI provider configuration
```

**GCP Pattern:**
```yaml
outputs:
  default:
    type: '@facets/gcp_cloud_account'
    providers:
      google:
        source: hashicorp/google
        version: ~> 6.12.0
        attributes:
          project: attributes.project_id
          region: attributes.region
      google-beta:
        source: hashicorp/google-beta
        version: ~> 6.12.0
        attributes:
          project: attributes.project_id
          region: attributes.region
```

## Spec Structure

All modules MUST organize their `spec.properties` with minimal required fields:

**Common Fields:**
- `region` or `location`: Cloud region/location selection (MANDATORY)
- `cloud_account`: Cloud account selection via API integration (MANDATORY)

**Example AWS Spec:**
```yaml
spec:
  type: object
  properties:
    region:
      type: string
      title: AWS Region
      x-ui-overrides-only: true
      x-ui-api-source:
        endpoint: /cc-ui/v1/dropdown/aws/regions-v2
        method: GET
        labelKey: region
        valueKey: region
    cloud_account:
      type: string
      title: Cloud Account
      x-ui-typeable: true
      x-ui-overrides-only: true
      x-ui-api-source:
        endpoint: /cc-ui/v1/accounts/
        method: GET
        labelKey: name
        valueKey: id
        filterConditions:
          - field: accountType
            value: CLOUD
          - field: provider
            value: AWS
  required:
    - cloud_account
    - region
```

### Allowed Configuration Fields
**These fields ARE acceptable:**
- Region/location selection
- Cloud account selection
- Provider-specific essential settings

**These fields are FORBIDDEN:**
- Detailed IAM configurations
- Custom authentication methods
- Provider feature flags (unless critical)
- Network or infrastructure settings

## Required Input Types

Cloud account modules typically do NOT consume other module outputs (they are foundational modules).

## Validation Checklist

Before completing any module:
- [ ] Outputs use `@facets/` namespace
- [ ] Default output uses cloud-specific type name
- [ ] Provider configuration properly structured
- [ ] All required authentication attributes included
- [ ] API integration for account/region selection configured
- [ ] Module validates successfully
- [ ] Security defaults hardcoded where applicable
