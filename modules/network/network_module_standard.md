# Network Module Standards

These instructions supplement the default Facets module generation guidelines for this repository.

## Repository Scope

This repository contains network modules for AWS VPC, Azure VNet, and GCP VPC. Each module creates cloud-optimized virtual networks with subnets, routing, and connectivity features.

## Design Philosophy

### Simplicity Over Flexibility
- Provide Kubernetes-optimized network configurations with sensible defaults
- Do NOT expose every possible networking option
- Auto-calculate subnets and routing where possible
- Use secure, production-ready defaults that don't require configuration
- Generate necessary networking components automatically

### Technology-Familiar Field Names
- Use field names familiar to cloud networking and Kubernetes users
- Do NOT invent new abstractions or terms
- Make modules configurable by developers who are not networking experts
- Abstract away complex subnet calculations and routing tables

### Security-First Defaults
- Enable encryption in transit by default where supported
- Configure secure network ACLs and security groups automatically
- Enable flow logs and monitoring by default
- Use private subnets with NAT gateways as default pattern
- Implement least-privilege network segmentation

## Module Conventions

### Naming Standards
- **Intent**: Use `network` for all cloud providers
- **Flavors**: Cloud-specific names (e.g., `aws_vpc`, `azure_network`, `gcp_vpc`)
- **Name Length Limits**: Ensure generated resource names comply with cloud provider constraints

- **All outputs and inputs MUST use `@facets/` namespace prefix**
- **STRICTLY FORBIDDEN: Using any output types that do NOT start with `@facets/`**

## Core Functionality Requirements

Every module MUST provide support for:

1. **Network Creation**
   - VPC/VNet creation with configurable CIDR blocks
   - Automatic subnet allocation across availability zones/regions
   - Support for multiple subnet types (public, private, database, etc.)

2. **Connectivity**
   - NAT Gateway configuration (single or per-AZ strategies)
   - Internet Gateway setup
   - Route table configuration
   - VPC/VNet peering support (where applicable)

3. **Service Endpoints**
   - Cloud service endpoints (S3, DynamoDB, Storage, etc.)
   - Private Link / Private Endpoint configuration
   - Configurable endpoint selection for cost optimization

4. **Network Security**
   - Network ACLs configured automatically
   - Flow logs enabled by default
   - DNS configuration
   - DHCP options (where applicable)

5. **Availability Zone Distribution**
   - Auto-select availability zones
   - Support for manual AZ selection
   - Ensure high availability across multiple AZs

## Module Structure

### Required Files
```
network/
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
- **Default output**: Use cloud-specific network detail types:
  - `@facets/aws-vpc-details` (AWS)
  - `@facets/azure-network-details` (Azure)
  - `@facets/gcp-network-details` (GCP)

### Standard Output Structure

**AWS Pattern:**
```yaml
outputs:
  default:
    type: '@facets/aws-vpc-details'
    title: AWS VPC Network Details
    description: Complete VPC configuration including subnets, route tables, and networking resources
```

**Azure Pattern:**
```yaml
outputs:
  default:
    type: '@facets/azure-network-details'
    title: Azure Virtual Network Details
    description: Complete VNet configuration including subnets and networking resources
```

**GCP Pattern:**
```yaml
outputs:
  default:
    type: '@facets/gcp-network-details'
    title: GCP VPC Network Details
    description: Complete VPC configuration including subnets and networking resources
```

## Spec Structure

All modules MUST organize their `spec.properties` using **GROUPED OBJECTS** where applicable:

**Common Groups:**
- Network CIDR/address space configuration
- Availability zone selection
- NAT gateway configuration
- VPC/service endpoints configuration
- Tags/labels

### Cloud-Specific Spec Examples

**AWS VPC Pattern:**
```yaml
spec:
  type: object
  properties:
    vpc_cidr:
      type: string
      title: VPC CIDR Block
      description: CIDR block for the VPC (must be /16 for optimal Kubernetes workloads)
      pattern: ^([0-9]{1,3}\.){3}[0-9]{1,3}/16$
      x-ui-placeholder: 10.0.0.0/16

    auto_select_azs:
      type: boolean
      title: Auto Select Availability Zones
      default: true

    availability_zones:
      type: array
      title: Availability Zones
      x-ui-visible-if:
        field: spec.auto_select_azs
        values: [false]
      minItems: 2
      maxItems: 5

    nat_gateway:
      type: object
      title: NAT Gateway Configuration
      properties:
        strategy:
          type: string
          enum: [single, per_az]
          default: single

    vpc_endpoints:
      type: object
      title: VPC Endpoints Configuration
      x-ui-toggle: true
      properties:
        enable_s3:
          type: boolean
          default: true
        enable_ecr_api:
          type: boolean
          default: true
        # ... additional endpoints

    tags:
      type: object
      title: Additional Tags
      x-ui-yaml-editor: true

  required:
    - vpc_cidr
    - nat_gateway
```

**Azure VNet Pattern:**
```yaml
spec:
  type: object
  properties:
    address_space:
      type: array
      title: Address Space
      description: CIDR blocks for the Virtual Network
      items:
        type: string
        pattern: ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$

    subnets:
      type: object
      title: Subnets
      x-ui-toggle: true
      patternProperties:
        .*:
          type: object
          properties:
            address_prefix:
              type: string
              title: Address Prefix
            service_endpoints:
              type: array
              title: Service Endpoints

    tags:
      type: object
      title: Tags
      x-ui-yaml-editor: true
```

**GCP VPC Pattern:**
```yaml
spec:
  type: object
  properties:
    auto_create_subnetworks:
      type: boolean
      title: Auto Create Subnetworks
      default: false

    subnets:
      type: object
      title: Subnets
      x-ui-toggle: true
      patternProperties:
        .*:
          type: object
          properties:
            ip_cidr_range:
              type: string
              title: IP CIDR Range
            region:
              type: string
              title: Region
            private_ip_google_access:
              type: boolean
              default: true

    labels:
      type: object
      title: Labels
      x-ui-yaml-editor: true
```

### Allowed Configuration Fields

**These fields ARE acceptable:**
- CIDR blocks / address spaces
- Availability zone selection
- NAT gateway strategies
- VPC/service endpoint selection
- Subnet configuration (with auto-calculation support)
- Flow log settings
- DNS configuration
- Resource tags/labels

**These fields are FORBIDDEN:**
- Low-level route table configurations
- Detailed security group rules
- Custom DHCP option sets (unless essential)
- Peering configurations (should be separate module)
- VPN/Direct Connect configurations (should be separate modules)

## Required Input Types

All network modules MUST consume:

1. **Cloud Account** (MANDATORY):
   - `@facets/aws_cloud_account` (AWS VPC)
   - `@facets/azure_cloud_account` (Azure VNet)
   - `@facets/gcp_cloud_account` (GCP VPC)
   - Must specify provider configurations

## Development Workflow

### Pre-Planning Requirements
**BEFORE presenting any module plan:**
1. **Fetch existing output types** to understand available `@facets/` types
2. **IGNORE any output types that do NOT start with `@facets/`**
3. **CRITICAL: NEVER register output types that you need as inputs**
4. **Determine new output types** this module will create
5. **MANDATORY: Get explicit user approval** for ANY new output types
6. **Verify cloud-specific patterns** from existing modules
7. **Identify ALL required provider inputs** (cloud account)

### Required Plan Elements

**Spec Structure:**
- Use cloud-specific patterns from existing modules
- Use GROUPED OBJECTS for complex configurations
- Include essential network configuration
- Auto-calculate subnets where possible

**Input Requirements:**
- Cloud account input (MANDATORY): `@facets/{cloud}_cloud_account`
- **STRICTLY FORBIDDEN**: Using any non-`@facets/` prefixed types

**Output Types:**
- Default output: `@facets/{cloud}-network-details` or `@facets/{cloud}-vpc-details`
- **CRITICAL**: ALL output types MUST start with `@facets/`

## Cloud-Specific Considerations

### AWS VPC
- Support for multiple subnet types (public, private, database)
- VPC endpoint configuration for cost optimization
- NAT Gateway strategies (single vs per-AZ)
- Automatic subnet calculation across AZs
- Flow logs to CloudWatch

### Azure VNet
- Support for multiple address spaces
- Service endpoint configuration
- Network Security Groups (NSG) auto-configured
- Subnet delegation support
- Integration with Azure Private Link

### GCP VPC
- Global VPC with regional subnets
- Private Google Access enabled by default
- Cloud NAT configuration
- VPC Flow Logs configuration
- Custom subnet mode recommended

## Validation Checklist

Before completing any module:
- [ ] Generated resource names comply with cloud provider limits
- [ ] Outputs use `@facets/` namespace
- [ ] Default output uses cloud-specific network details type
- [ ] Inputs only consume `@facets/` namespaced types
- [ ] Cloud account input configured
- [ ] Security defaults hardcoded (encryption, flow logs, etc.)
- [ ] Networking components auto-generated
- [ ] Spec uses appropriate structure for cloud provider
- [ ] Module validates successfully
- [ ] Provider configurations properly reference cloud account input
