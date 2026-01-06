# Facets Modules Repository

## Overview

This repository contains Infrastructure as Code (IaC) modules for the Facets platform. These modules are Terraform-based implementations that provision and manage cloud infrastructure resources across AWS, Azure, and GCP.

**Purpose:** Provide reusable, standardized infrastructure modules organized by intent and flavor.

**Target Users:** Platform engineers, DevOps teams, and AI agents working with Facets infrastructure.

## Repository Structure

```
facets-modules-redesign/
├── aws/                    # AWS-specific modules
├── azure/                  # Azure-specific modules
├── gcp/                    # GCP-specific modules
├── common/                 # Cloud-agnostic Kubernetes modules
├── datastore/             # Database and caching modules
├── outputs/               # Output type definitions (@facets/* namespace)
├── project-type/          # Project type templates (see docs/project-types.md)
└── docs/                  # Documentation
```

### Directory Organization

**Cloud Provider Directories** (`aws/`, `azure/`, `gcp/`)
- Organized by resource intent (e.g., `network`, `kubernetes_cluster`, `service`)
- Each intent contains flavor implementations (e.g., `aws_vpc`, `eks`, `gke`)
- Version-based subdirectories (e.g., `1.0`)

**Common Directory**
- Cloud-agnostic Kubernetes modules
- Platform components (cert-manager, ingress, prometheus, etc.)
- Organized similarly: `intent/flavor/version/`

**Datastore Directory**
- Database, cache, queue, and messaging modules
- Organized by technology: `postgres/`, `redis/`, `kafka/`, etc.
- Each technology has cloud-specific flavors (e.g., `aws-rds`, `gcp-cloudsql`)

**Outputs Directory**
- Output type definitions using `@facets/` namespace
- Each output type has an `outputs.yaml` file
- Defines schemas for data passed between modules

**Project-Type Directory**
- Complete project templates for different cloud providers
- See `docs/project-types.md` for detailed information

## Module Anatomy

### Standard Module Structure

Every module version directory (e.g., `aws/network/aws_vpc/1.0/`) contains:

```
1.0/
├── facets.yaml          # Module metadata and specifications
├── main.tf             # Core Terraform resources
├── variables.tf        # Required Terraform variables
├── outputs.tf          # Output definitions and interfaces
├── locals.tf           # Local computations (optional)
└── README.md           # Auto-generated documentation
```

### Required Terraform Variables

Every module MUST include these variables in `variables.tf`:

```hcl
variable "instance" {}
variable "instance_name" {}
variable "environment" {}
variable "inputs" {}
```

### facets.yaml Structure

The `facets.yaml` file is the module's metadata descriptor:

```yaml
intent: <resource_type>          # e.g., network, service, postgres
flavor: <implementation>         # e.g., aws_vpc, eks, rds
version: '1.0'                   # Module version
description: <human_readable>
clouds: [aws|azure|gcp]         # Supported cloud providers

spec:
  type: object
  properties:                    # User-configurable parameters
    # Organized in grouped objects (see standards below)
  required: [...]               # Required fields

outputs:
  default:
    type: '@facets/output_type_name'  # MUST use @facets/ namespace
    providers:                   # Terraform provider configuration
      aws|azure|gcp:
        source: ...
        version: ...
        attributes: ...
  interfaces:                    # Optional standardized interfaces
    type: '@facets/interface_type'

sample:                          # Example usage
  version: '1.0'
  flavor: <flavor>
  kind: <intent>
  spec: { ... }

iac:
  validated_files: [...]        # Files validated during upload
```

## Key Concepts

### Intent vs Flavor

**Intent:** What you want to create (the resource type)
- Examples: `network`, `kubernetes_cluster`, `postgres`, `service`
- Represents the logical purpose of the resource

**Flavor:** How you want to create it (the implementation)
- Examples: `aws_vpc`, `eks`, `gke`, `rds`, `k8s_standard`
- Represents the specific cloud provider or technology variant

**Path Pattern:** `<cloud>/<intent>/<flavor>/<version>/`

### Output Types

Output types define the data contracts between modules using the `@facets/` namespace.

**Location:** `outputs/<type_name>/outputs.yaml`

**Naming Convention:**
- Use `@facets/` prefix (MANDATORY)
- Format: `@facets/<descriptive_name>`
- Examples: `@facets/aws_cloud_account`, `@facets/postgres`, `@facets/redis-interface`

**Structure:**
```yaml
name: '@facets/type_name'
properties:
    properties:
        attributes:
            properties:
                field_name:
                    description: ...
                    type: string
            type: object
    type: object
providers:
    - name: aws
      source: hashicorp/aws
      version: = 5.0.0
```

### Module Inputs and Outputs

**Inputs:** Modules consume outputs from other modules
- Specified in `facets.yaml` under `inputs` or within spec properties
- MUST use `@facets/` namespace types only
- Examples: `@facets/aws_cloud_account`, `@facets/vpc`, `@facets/kubernetes-details`

**Outputs:** Modules produce typed outputs
- Defined in `outputs.tf` using `output_interfaces` and `output_attributes`
- Must match the schema defined in corresponding `outputs/<type>/outputs.yaml`
- Two types:
  - **default:** Implementation-specific output (e.g., `@facets/rds`)
  - **interfaces:** Standardized cross-flavor output (e.g., `@facets/postgres-interface`)

## Module Standards

### Datastore Modules

Special standards apply to database, cache, and queue modules (see `datastore/mcp_instructions/datastore_module_standards.md`):

**Spec Structure (MANDATORY - Grouped Objects):**
```yaml
spec:
  properties:
    version_config:        # Version and basic configuration
      type: object
      properties:
        version: ...       # Only last 3 major versions

    sizing:               # Performance and storage
      type: object
      properties:
        instance_class: ...
        allocated_storage: ...

    restore_config:       # Backup and restore
      type: object
      properties:
        restore_from_backup: ...
        source_db_instance_identifier: ...

    imports:              # Import existing resources
      type: object
      properties:
        # Field names MUST match terraform import requirements
```

**Design Principles:**
- Simplicity over flexibility
- Developer-centric (NOT Ops-centric)
- Secure defaults (hardcoded, not configurable)
- Technology-familiar field names
- Support last 3 major versions only

**Forbidden Fields:**
- NO monitoring configurations
- NO alerting settings
- NO backup schedules (auto-configured to 7 days)
- NO networking details (VPC, subnets, security groups)
- NO maintenance windows

**Required Features:**
- Version management (last 3 major versions)
- Authentication & security (auto-configured)
- Sizing & performance configuration
- Backup & restore functionality
- Import existing resources support

### Output Interfaces

Standardized output structures for cross-flavor compatibility:

**Reader/Writer Datastores:**
```hcl
output_interfaces = {
  writer = {
    host = "<endpoint>"
    username = "<username>"
    password = "<password>"
    connection_string = "<protocol>://<username>:<password>@<host>:<port>/<db>"
  }
  reader = { ... }
}
```

**Clustered Datastores:**
```hcl
output_interfaces = {
  cluster = {
    endpoint = "<host1>:<port>,<host2>:<port>"
    connection_string = "..."
    endpoints = {
      "0" = "<host1>:<port>"
      "1" = "<host2>:<port>"
    }
  }
}
```

## Working with This Repository

### Finding Modules

**By Intent and Flavor:**
1. Navigate to cloud directory: `aws/`, `azure/`, `gcp/`, `common/`, or `datastore/`
2. Go to intent directory (e.g., `network/`, `postgres/`)
3. Select flavor directory (e.g., `aws_vpc/`, `rds/`)
4. Enter version directory (e.g., `1.0/`)

**Search for facets.yaml files:**
```bash
find . -name "facets.yaml" -path "*/<intent>/<flavor>/*"
```

**Grep for specific intent:**
```bash
grep -r "^intent: postgres" --include="facets.yaml"
```

### Understanding Module Dependencies

**Check Required Inputs:**
1. Open `facets.yaml`
2. Look for input type references in spec properties
3. Search for `type: '@facets/...'` patterns
4. These indicate dependencies on other modules

**Check Produced Outputs:**
1. Look at `outputs` section in `facets.yaml`
2. Note the output type names
3. Cross-reference with `outputs/<type>/outputs.yaml`

### Creating New Modules

**Checklist:**
1. Determine intent and flavor
2. Create directory structure: `<cloud>/<intent>/<flavor>/1.0/`
3. Create required files: `facets.yaml`, `main.tf`, `variables.tf`, `outputs.tf`
4. Define spec structure (use grouped objects for datastores)
5. Implement Terraform resources
6. Define output_interfaces and output_attributes
7. Register output types in `outputs/` directory
8. Validate module
9. Generate README.md

**Important Rules:**
- ALL output types MUST use `@facets/` namespace
- Input types MUST already exist (never create inputs)
- Follow datastore standards for database/cache modules
- Include import declarations for major resources
- Validate against cloud provider documentation (especially version enums)

## Quick Reference

### Common File Locations

| What | Where |
|------|-------|
| AWS VPC module | `aws/network/aws_vpc/1.0/` |
| EKS cluster | `aws/kubernetes_cluster/eks/1.0/` |
| GKE cluster | `gcp/kubernetes_cluster/gke/1.0/` |
| AKS cluster | `azure/kubernetes_cluster/aks/1.0/` |
| AWS service | `aws/service/aws/1.0/` |
| Postgres (RDS) | `datastore/postgres/aws-rds/1.0/` |
| Redis (ElastiCache) | `datastore/redis/aws-elasticache/1.0/` |
| Ingress | `common/ingress/nginx_k8s/1.0/` |
| Cert Manager | `common/cert_manager/standard/1.0/` |
| Output types | `outputs/<type_name>/outputs.yaml` |
| Datastore standards | `datastore/mcp_instructions/datastore_module_standards.md` |
| Project types guide | `docs/project-types.md` |
| Import guide | `docs/import-project-type-documentation.md` |

### Common Commands

**Find all modules of a specific intent:**
```bash
find . -type f -name "facets.yaml" -exec grep -l "^intent: network" {} \;
```

**List all output types:**
```bash
ls -1 outputs/*/outputs.yaml
```

**Validate Terraform in a module:**
```bash
cd <module_path>
terraform init
terraform fmt -check
terraform validate
```

**Search for module by flavor:**
```bash
grep -r "^flavor: aws_vpc" --include="facets.yaml"
```

## AI Agent Guidelines

### When Reading This Repository

1. **Start with the intent:** Understand what resource type is needed
2. **Identify the cloud/technology:** AWS, Azure, GCP, or common
3. **Find the flavor:** Locate the specific implementation
4. **Read facets.yaml first:** This contains all metadata and specs
5. **Check dependencies:** Look for input types in the spec
6. **Review outputs:** Understand what the module produces

### When Creating Modules

1. **Check datastore standards:** If creating database/cache modules
2. **Verify output types exist:** Don't create types that should be inputs
3. **Use grouped objects:** For datastore specs (version_config, sizing, restore_config)
4. **Follow naming conventions:** `@facets/` namespace for all outputs
5. **Validate versions:** Ensure enum values match cloud provider docs
6. **Get user approval:** For new output types before creation
7. **Include import support:** Add import declarations for major resources

### When Modifying Modules

1. **Read existing implementation:** Never propose changes without reading
2. **Maintain compatibility:** Don't break existing output interfaces
3. **Follow established patterns:** Match the style of similar modules
4. **Update version if needed:** Consider bumping version for breaking changes
5. **Regenerate README:** If modifying specs or outputs

### Common Pitfalls to Avoid

- Using non-`@facets/` namespaced output types
- Creating flat spec structures for datastore modules (must use grouped objects)
- Adding Ops-centric fields to datastore modules
- Supporting more than last 3 major versions
- Including configurable security/backup settings (should be hardcoded)
- Forgetting to validate version enums against cloud provider docs
- Creating output types that you need as inputs

## Additional Resources

- **Project Types:** See `docs/project-types.md` for project type templates and usage
- **Raptor CLI:** https://github.com/Facets-cloud/raptor-releases
- **Datastore Standards:** `datastore/mcp_instructions/datastore_module_standards.md`
- **Import Documentation:** `docs/import-project-type-documentation.md`

## Repository Status

- **Branch:** master
- **Primary Use:** Module development and project type definitions
- **Module Upload:** Via Raptor CLI with project type import
- **Validation:** Automatic during upload (terraform fmt, validate, Trivy scan)
