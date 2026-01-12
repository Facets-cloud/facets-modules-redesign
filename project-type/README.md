# Project Types Guide

## Overview

Project types are pre-configured infrastructure templates that define a complete cloud environment with standardized resources. They combine multiple modules into a cohesive project structure that can be deployed via the Facets platform.

**Purpose:** Provide ready-to-use cloud environment templates with best practices and common configurations built-in.

## Repository Structure

```
project-type/
├── aws/
│   ├── project-type.yml      # AWS project metadata
│   └── base/                 # Default resource instances
│       ├── stack.json
│       └── <intent>/instances/<name>.json
├── azure/
│   ├── project-type.yml      # Azure project metadata
│   └── base/                 # Default resource instances
├── gcp/
│   ├── project-type.yml      # GCP project metadata
│   └── base/                 # Default resource instances
└── ...
```

## Project Type Metadata

### project-type.yml Structure

Each project type is defined by a `project-type.yml` file:

```yaml
name: <ProjectTypeName>          # Display name (e.g., AWS, Azure, GCP)
description: <human_readable>    # Description of the project type

# Git repository details
gitUrl: <repository_url>         # Git repository containing modules
gitRef: <branch_or_tag>          # Git branch or tag (e.g., master, v1.0.0)
baseTemplatePath: <path>         # Path to base templates within repo

# IaC modules to include
modules:
  - intent: <intent>             # Resource type
    flavor: <flavor>             # Implementation variant
  - intent: <intent>
    flavor: <flavor>
  # ... more modules
```

### Example: AWS Project Type

```yaml
name: AWS
description: AWS project type with EKS and common services

# Git repository details
gitUrl: https://github.com/Facets-cloud/facets-modules-redesign.git
gitRef: master
baseTemplatePath: project-type/aws/base

# IaC modules to include
modules:
  # Cloud Account Setup
  - intent: cloud_account
    flavor: aws_provider

  # Networking
  - intent: network
    flavor: aws_vpc

  # Kubernetes Cluster
  - intent: kubernetes_cluster
    flavor: eks

  # Node Pools
  - intent: kubernetes_node_pool
    flavor: aws

  # Application Services
  - intent: service
    flavor: aws

  # Common Modules
  - intent: cert_manager
    flavor: standard

  - intent: ingress
    flavor: nginx_k8s

  - intent: prometheus
    flavor: k8s_standard
```

## Base Templates

The `base/` directory contains default resource instance configurations:

### Structure

```
base/
├── stack.json                           # Stack configuration
├── cloud_account/
│   └── instances/
│       └── cloud.json                   # Cloud account instance
├── network/
│   └── instances/
│       └── network.json                 # Network instance
├── kubernetes_cluster/
│   └── instances/
│       └── cluster.json                 # Cluster instance
├── service/
│   └── instances/
│       └── service.json                 # Service instance
└── ...
```

### Instance File Format

Each `<name>.json` file defines a resource instance:

```json
{
  "kind": "<intent>",
  "flavor": "<flavor>",
  "version": "1.0",
  "disabled": false,
  "spec": {
    // Intent-specific configuration
  }
}
```

**Example: Network Instance**
```json
{
  "kind": "network",
  "flavor": "aws_vpc",
  "version": "1.0",
  "disabled": false,
  "spec": {
    "vpc_cidr": "10.0.0.0/16",
    "availability_zones": 3
  }
}
```

## Module Discovery

When importing a project type with modules:

1. **Module List:** The `modules` array in `project-type.yml` specifies which modules to include
2. **Module Discovery:** Raptor CLI recursively searches the `--modules-dir` for matching `facets.yaml` files
3. **Matching Criteria:** Modules are matched by `intent` and `flavor` fields
4. **Automatic Upload:** Matched modules are automatically uploaded and published

**Example:**
```yaml
modules:
  - intent: postgres
    flavor: aws-rds
```

Raptor will find: `datastore/postgres/aws-rds/1.0/facets.yaml`

## Output Types Integration

When importing project types with `--outputs-dir`:

1. **Extract Requirements:** Raptor scans all modules for required output types
2. **Search Outputs:** Looks for matching `outputs.yaml` files in `--outputs-dir`
3. **Create Types:** Automatically creates output types in the control plane
4. **Skip Existing:** Types that already exist are skipped

**Example:**
```bash
raptor import project-type \
  -f ./project-type/aws/project-type.yml \
  --modules-dir ./modules \
  --outputs-dir ./outputs
```

## Importing Project Types

### Using Raptor CLI

**Basic Import (No Modules):**
```bash
raptor import project-type -f ./project-type/aws/project-type.yml
```

**Import with Modules:**
```bash
raptor import project-type \
  -f ./project-type/aws/project-type.yml \
  --modules-dir ./modules \
  --outputs-dir ./outputs
```

**Private Repository:**
```bash
# Get VCS account ID
raptor get accounts --type VERSION_CONTROL

# Import with VCS account
raptor import project-type \
  -f ./project-type/aws/project-type.yml \
  --vcs-account-id acc_xyz123 \
  --modules-dir ./modules \
  --outputs-dir ./outputs
```

### Command Flags

| Flag | Description | Required |
|------|-------------|----------|
| `-f, --file` | Path to project-type.yml | Yes |
| `--vcs-account-id` | VCS account ID for private repos | No |
| `--modules-dir` | Directory containing modules to upload | No |
| `--outputs-dir` | Directory containing output type definitions | No |
| `--useBranch` | Enable git branch usage (default: true) | No |
| `-o, --output` | Output format (table\|json\|yaml) | No |

### Import Process

1. **Read Metadata:** Parses `project-type.yml`
2. **Create/Update Project Type:** Upserts the project type in control plane
3. **Create Output Types:** (if `--outputs-dir` provided) Creates required output types
4. i. **Discover Modules:** (if `--modules-dir` provided) Finds matching modules
   ii. **Validate Modules:** Runs terraform fmt, validate, and security scans
   iii. **Upload Modules:** Publishes modules to control plane
   iv. **Report Results:** Shows success/failure for each step

### Validation

During import of project type, if modules directory is provided, then each module undergoes validation:

- Facets.yaml structure validation
- Terraform formatting check (`terraform fmt -check`)
- Terraform validation (`terraform init && terraform validate`)
- Required variables check (instance, instance_name, environment, inputs)
- Security scanning with Trivy (if installed)
- Output processing and type creation

## Creating New Project Types

### Step 1: Create Metadata File

Create `project-type/<name>/project-type.yml`:

```yaml
name: MyProject
description: Custom project type
gitUrl: https://github.com/myorg/modules.git
gitRef: main
baseTemplatePath: project-type/myproject/base

modules:
  - intent: cloud_account
    flavor: aws_provider
  - intent: network
    flavor: aws_vpc
  # ... more modules
```

### Step 2: Create Base Templates

Create directory structure:
```bash
mkdir -p project-type/<name>/base
```

Add `stack.json` and instance configurations for each module.

### Step 3: Import and Test

```bash
raptor import project-type \
  -f ./project-type/<name>/project-type.yml \
  --modules-dir ./modules \
  --outputs-dir ./outputs
```

## Project Type Management

### Updating Project Types

Project types use upsert behavior - re-importing updates existing types:

```bash
# Modify project-type.yml
vim ./project-type/aws/project-type.yml

# Re-import to update
raptor import project-type -f ./project-type/aws/project-type.yml
```

### Listing Project Types

```bash
# List all project types
raptor get project-types

# Get specific project type
raptor get project-types AWS -o yaml
```

### Verifying Module Upload

```bash
# List modules by intent
raptor get iac-module --type network

# Get specific module
raptor get iac-module --type network --flavor aws_vpc
```

## Best Practices

### Module Selection

1. **Include Foundational Modules:**
   - Cloud account provider
   - Network/VPC
   - Kubernetes cluster (if applicable)

2. **Add Platform Components:**
   - Ingress controllers
   - Certificate managers
   - Monitoring (Prometheus)

3. **Include Common Services:**
   - Application service modules
   - Common datastores
   - Secrets management

### Base Template Organization

1. **Minimal Configuration:** Provide sensible defaults
2. **Environment Agnostic:** Avoid hardcoded environment-specific values
3. **Dependency Order:** Ensure instances are ordered by dependencies
4. **Disabled Flag:** Use `disabled: true` for optional components

### Version Management

1. **Git Refs:** Use stable branches or tags (e.g., `main`, `v1.0.0`)
2. **Module Versions:** Specify version in module definitions
3. **Compatibility:** Ensure module versions are compatible with each other

## Troubleshooting

### Module Not Found

**Problem:** Module specified in project-type.yml not found during import

**Solution:**
- Verify module exists in `--modules-dir`
- Check intent and flavor match exactly in `facets.yaml`
- Ensure module path follows: `<cloud>/<intent>/<flavor>/<version>/facets.yaml`

### Module Upload Failure

**Problem:** Module validation fails during upload

**Solution:**
- Run terraform validate locally in the module directory
- Check for required variables (instance, instance_name, environment, inputs)
- Review Terraform syntax and formatting
- Use `--skip-validation` for debugging (not recommended for production)

### Output Type Conflicts

**Problem:** Output type already exists with different schema

**Solution:**
- Review existing output type: `raptor get output-types @facets/type_name`
- Ensure schema compatibility
- Consider using a different output type name if schemas are incompatible

### VCS Access Issues

**Problem:** Cannot access private repository

**Solution:**
- Verify VCS account configured: `raptor get accounts --type VERSION_CONTROL`
- Check repository permissions for the VCS account
- Ensure `--vcs-account-id` is correct

## Examples

### Complete AWS Project Type

See: `project-type/aws/project-type.yml`

Key modules:
- AWS provider setup, VPC networking, EKS cluster, Node pools, Application services, Common Kubernetes components

### Complete Azure Project Type

See: `project-type/azure/project-type.yml`

Key modules:
- Azure provider setup, Virtual network, AKS cluster, Node pools, Application services, Common Kubernetes components

### Complete GCP Project Type

See: `project-type/gcp/project-type.yml`

Key modules:
- GCP provider setup, VPC networking, GKE cluster, Node pools, Application services, Common Kubernetes components

## Related Documentation

- **Main README:** `../README.md` - Module development guide
- **Import Guide:** `import-project-type-documentation.md` - Detailed Raptor CLI usage
- **Datastore Standards:** `../datastore/mcp_instructions/datastore_module_standards.md`
- **Raptor CLI:** https://github.com/Facets-cloud/raptor-releases
