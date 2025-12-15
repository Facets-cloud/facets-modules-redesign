# Importing Project Types with Raptor CLI

## Overview

The `raptor import project-type` command allows you to import or update project types in Facets Control Plane. This command supports:

- **Upsert behavior** - Creates new or updates existing project types
- **Public repositories** - Import from any public Git repository
- **Private repositories** - Import from private repositories with VCS account credentials
- **Automatic module uploads** - Upload IaC modules alongside project types

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Type Metadata Format](#project-type-metadata-format)
- [Import Examples](#import-examples)
- [Uploading IaC Modules](#uploading-iac-modules)
- [Complete Workflow](#complete-workflow)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Install Raptor CLI

Raptor is required to import project types. Follow the installation guide:

**📦 [Raptor Installation Guide](https://github.com/Facets-cloud/raptor-releases)**

---

## Quick Start

### Basic Import

```bash
# Create a project-type.yml file with all required fields
raptor import project-type -f ./project-type.yml
```

### Import with Module Uploads

```bash
# Import project type and upload all specified modules
raptor import project-type -f ./project-type.yml --modules-dir ./modules --outputs-dir ./outputs
```

### Private Repository

```bash
# Import from private repository using VCS account
raptor import project-type -f ./project-type.yml --vcs-account-id acc_123456
```

---

## Project Type Metadata Format

The YAML file must contain all required fields including git repository details.

### Required Fields

```yaml
name: string                    # Project type name (required)
description: string             # Human-readable description (required)
gitUrl: string                  # Git repository URL (required)
gitRef: string                  # Git branch/tag (required)
baseTemplatePath: string        # Path to templates within repo (required)
```

### Optional Fields

```yaml
modules: []object               # IaC modules to include (optional)
```

### Complete Example

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
    flavor: aws_network

  # Kubernetes Cluster
  - intent: kubernetes_cluster
    flavor: eks

  # Node Pools
  - intent: kubernetes_node_pool
    flavor: aws

  # Application Services
  - intent: service
    flavor: aws
```

### Module Entry Format

Each module entry requires:

| Field | Description | Example |
|-------|-------------|---------|
| `intent` | Resource type/intent name | `network`, `service`, `postgres` |
| `flavor` | Module variant/implementation | `aws_vpc`, `k8s`, `rds` |

**Note**: The module path is automatically discovered by recursively searching for `facets.yaml` files in the `--modules-dir` that match the specified `intent` and `flavor`.

---

## Import Examples

### Example 1: Public Repository

```yaml
# aws-project.yml
name: AWS
description: AWS project type with common configurations
gitUrl: https://github.com/myorg/project-templates.git
gitRef: main
baseTemplatePath: templates/aws
modules:
  - intent: cloud_account
    flavor: aws_provider
```

```bash
raptor import project-type -f ./aws-project.yml
```

### Example 2: Private Repository

```yaml
# internal-platform.yml
name: InternalPlatform
description: Internal platform services
gitUrl: https://github.com/myorg/private-templates.git
gitRef: v1.0.0
baseTemplatePath: platform/templates
modules:
  - intent: service
    flavor: standard
```

```bash
# 1. Get your VCS account ID
raptor get vcs-accounts

# 2. Import with VCS account
raptor import project-type -f ./internal-platform.yml --vcs-account-id acc_xyz123
```

### Example 3: Multi-Cloud Project Type

```yaml
# multi-cloud.yml
name: MultiCloud
description: Multi-cloud project type supporting AWS and GCP
gitUrl: https://github.com/platform-team/multi-cloud.git
gitRef: main
baseTemplatePath: project-types/multi-cloud
modules:
  - intent: service
    flavor: k8s
  - intent: postgres
    flavor: cloud_sql
```

```bash
raptor import project-type -f ./multi-cloud.yml
```

### Example 4: Update Existing Project Type

Re-running the import command updates the existing project type (upsert behavior):

```bash
# Modify your YAML file
vim ./aws-project.yml

# Re-import to update
raptor import project-type -f ./aws-project.yml
```

---

## Uploading IaC Modules

The `--modules-dir` flag automatically uploads IaC modules specified in your project type metadata.

### How It Works

1. **Specify modules in YAML** (see format above)

2. **Run import with `--modules-dir`:**

```bash
raptor import project-type -f ./aws-project.yml --modules-dir /path/to/modules
```

3. **Raptor will:**
   - Read module intent and flavor from YAML
   - Recursively search `--modules-dir` for matching `facets.yaml` files
   - Match modules by comparing `intent` and `flavor` fields in each `facets.yaml`
   - If `--outputs-dir` is provided:
     - Extract output types from modules' `inputs.*.type` and `outputs.*.type`
     - Discover and create required output types before uploading modules
   - Upload each discovered module with full validation
   - Create output types automatically from `output_interfaces` and `output_attributes` (unless skipped)
   - Report success/failure for each module

**Module Discovery**: Raptor automatically finds modules by walking through the directory tree and checking each `facets.yaml` file. You don't need to specify exact paths - just provide the intent and flavor, and Raptor will find the matching module.

**Output Type Creation**: If `--outputs-dir` is provided, Raptor will automatically:
1. Scan all modules for required output types (from inputs and outputs)
2. Search for matching `outputs.yaml` files in `--outputs-dir`
3. Create those output types before uploading modules
4. Skip types that already exist

### Example Output

```
Reading metadata from file: ./aws-project.yml

Creating project type 'AWS' in Control Plane...

✓ Project type created successfully
  Name: AWS
  Description: AWS project type with common configurations
  ID: 691d8859a1985a048d8fef4f
  Template Path: project-type/aws/base

📦 Uploading IaC modules...

🔧 Creating output types...
  Creating output type @facets/aws_cloud_account...
  ✓ Created output type @facets/aws_cloud_account
  ✓ Created: 1 output types

  [1/3] Discovering module cloud_account/aws_provider...
  [1/3] Found at: aws/cloud_account/aws_provider/1.0
  [1/3] Uploading cloud_account/aws_provider...

=== Validating Module ===
✓ Checking facets.yaml...
✅ facets.yaml validated successfully
✓ Running terraform fmt...
🎨 Terraform files formatted
✓ Running terraform validate...
🔍 Terraform validation successful

=== Processing Outputs ===
✓ Found output_interfaces and/or output_attributes
✓ Generating output files...
✅ Generated output files: output-lookup-tree.json, output.facets.yaml

Uploading module cloud_account/aws_provider/...
✓ Module uploaded successfully (ID: 691d9093a1985a048d8fef5c)
  Stage: PUBLISHED

  [1/3] ✓ Uploaded and published cloud_account/aws_provider
  [2/3] Uploading network/aws_vpc...
  ...

📊 Module Upload Summary:
  ✓ Uploaded: 3
  ❌ Failed: 0
```

### Module Validation

Each module is automatically validated during upload:

- ✅ **facets.yaml structure** - Validates metadata format
- ✅ **Terraform formatting** - Runs `terraform fmt -check`
- ✅ **Terraform validation** - Runs `terraform init` and `terraform validate`
- ✅ **Required variables** - Checks for `instance`, `instance_name`, `environment`, `inputs`
- ✅ **Security scanning** - Runs Trivy (if installed) for HIGH/CRITICAL vulnerabilities
- ✅ **Output processing** - Parses `output_interfaces` and `output_attributes` to create output types

### Module Structure Requirements

Each module directory must contain:

```
module-name/
├── facets.yaml          # Module metadata
├── variables.tf         # Required variables
├── main.tf             # Main Terraform code
├── outputs.tf          # Output definitions (optional)
└── *.tf                # Other Terraform files
```

**Required in `variables.tf`:**
```hcl
variable "instance" {}
variable "instance_name" {}
variable "environment" {}
variable "inputs" {}
```

**Output definitions in `outputs.tf`:**
```hcl
locals {
  output_interfaces = {
    # Standardized connection interfaces
    http = {
      host = "..."
      port = 8080
    }
  }

  output_attributes = {
    # Resource-specific attributes
    vpc_id = "..."
    cluster_name = "..."
  }
}
```

---

## Complete Workflow

### Step 1: Create Metadata File

```yaml
# aws-project.yml
name: AWS
description: AWS project type
gitUrl: https://github.com/myorg/templates.git
gitRef: main
baseTemplatePath: project-type/aws/base
modules:
  - intent: cloud_account
    flavor: aws_provider
```

### Step 2: Import Project Type

```bash
# Without modules
raptor import project-type -f ./aws-project.yml

# With modules
raptor import project-type -f ./aws-project.yml --modules-dir ./modules
```

### Step 4: Verify Import

```bash
# List project types
raptor get project-types

# Get specific project type
raptor get project-types AWS -o yaml
```

### Step 5: Verify Module Upload

Modules are automatically uploaded and published during import. You can verify them with:

```bash
# List uploaded modules
raptor get iac-module --type cloud_account
```

---

## Troubleshooting

### Module Upload Failures

**Problem:** Module validation fails with Terraform errors

**Solution:**
1. Check Terraform syntax in the failing module
2. Ensure all required variables are present
3. Run `terraform validate` locally in the module directory
4. Upload manually with more control:
   ```bash
   raptor create iac-module -f /path/to/module --skip-validation
   ```

---

**Problem:** Module conflicts with built-in Facets module

**Error:**
```
Cannot update Facets built-in module with intent network and flavor aws_vpc.
Please choose a different flavor.
```

**Solution:**
Use a different flavor name in your module's `facets.yaml`:
```yaml
intent: network
flavor: aws_vpc_custom  # Changed from aws_vpc
version: 1.0
```

---

**Problem:** Output type creation fails

**Solution:**
1. Ensure your module has proper `output_interfaces` and `output_attributes` in `outputs.tf`
2. Create output types manually:
   ```bash
   raptor create output-type @custom/my-output -f output-schema.yaml
   ```

---

### Git Repository Access

**Problem:** Cannot access private repository

**Solution:**
1. Verify your VCS account is configured in Facets Control Plane
2. Check VCS account permissions
3. Ensure `--vcs-account-id` matches your configured account
4. List VCS accounts:
   ```bash
   raptor get accounts --type VERSION_CONTROL
   ```

---

### Metadata Validation

**Problem:** Missing required fields

**Solution:**
Ensure your YAML has all required fields:
```yaml
name: MyProject                    # Required
description: My description        # Required
gitUrl: https://...               # Required
gitRef: main                      # Required
baseTemplatePath: path/to/base    # Required
```

**Note:** `allowedClouds` is automatically set to `["AWS", "AZURE", "GCP", "KUBERNETES"]` and should not be included in the YAML file.

---

## Command Reference

```bash
# Basic import
raptor import project-type -f <YAML_FILE>

# Import from private repository
raptor import project-type -f <YAML_FILE> --vcs-account-id <ACCOUNT_ID>

# Import with module uploads
raptor import project-type -f <YAML_FILE> --modules-dir <MODULES_DIR> --outputs-dir <OUTPUTS_DIR>

# Combined
raptor import project-type -f <YAML_FILE> \
  --vcs-account-id <ACCOUNT_ID> \
  --modules-dir <MODULES_DIR> \
  --outputs-dir <OUTPUTS_DIR>
```

### Flags

| Flag | Description | Required |
|------|-------------|----------|
| `-f, --file` | YAML metadata file | ✅ Yes |
| `--vcs-account-id` | VCS account ID for private repos | ❌ No (only for private repos) |
| `--modules-dir` | Local modules directory | ❌ No |
| `--outputs-dir` | Local directory containing output type definitions | ❌ No (required if modules need output types) |
| `--useBranch` | Enable git branch usage | ❌ No (default: true) |
| `-o, --output` | Output format (table\|json\|yaml) | ❌ No |

---

## FAQ

**Q: Do I need to specify the project type name in the command?**

A: No, the name is read from the YAML file's `name` field.

**Q: Can I update an existing project type?**

A: Yes! The import command has upsert behavior - it will update existing project types with the same name.

**Q: What's the difference between public and private repository imports?**

A: Only the `--vcs-account-id` flag. Private repos need a VCS account configured in Control Plane for authentication.

**Q: Do I need to upload modules every time?**

A: No. If modules are already uploaded, they will be skipped. Use `--modules-dir` only when you want to upload new or updated modules.

**Q: How do I get a VCS account ID?**

A: Run `raptor get accounts --type VERSION_CONTROL` to list configured VCS accounts.

**Q: What if my repository uses a different branch structure?**

A: Specify the branch in the `gitRef` field in your YAML (e.g., `develop`, `feature/new-modules`, tags like `v1.0.0`).

**Q: Can I test the import without creating a project type?**

A: The command doesn't have a dry-run mode, but you can verify your YAML structure and then delete the project type if needed.

**Q: Are modules automatically published after import?**

A: Yes! Modules are automatically uploaded and published in PUBLISHED stage during import. They are immediately available for use.

---

## Additional Resources

- [Raptor CLI GitHub](https://github.com/Facets-cloud/raptor-releases)
