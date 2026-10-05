# EKS Standard Module

## Overview

This Facets module creates an Amazon EKS (Elastic Kubernetes Service) cluster with managed node groups using the official [terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks) module.

**Important:** This is the `eks_standard` flavor which does **NOT** support EKS Auto Mode. EKS Auto Mode is explicitly disabled in this module. For Auto Mode support, use a separate `eks_auto` flavor module.

## Module Details

- **Intent:** `kubernetes_cluster`
- **Flavor:** `eks_standard`
- **Version:** `1.0`
- **Cloud:** AWS

## Features

### Core Capabilities

- ✅ **Managed Node Groups**: Full support for EKS managed node groups with customizable configurations
- ✅ **Multiple Node Groups**: Support for multiple node groups with different instance types and configurations
- ✅ **Auto Scaling**: Configurable min/max/desired capacity per node group
- ✅ **Spot and On-Demand**: Support for both SPOT and ON_DEMAND capacity types
- ✅ **EKS Add-ons**: Managed add-ons for VPC CNI, Kube Proxy, and CoreDNS
- ✅ **Secrets Encryption**: Optional KMS-based encryption for Kubernetes secrets
- ✅ **Provider Exposure**: Exposes Kubernetes and Helm providers for dependent modules
- ✅ **Endpoint Access Control**: Configurable public/private API endpoint access

### Explicitly Disabled

- ❌ **EKS Auto Mode**: This flavor does NOT support EKS Auto Mode

## Dependencies (Inputs)

This module requires the following inputs:

### 1. AWS Cloud Account
- **Type:** `@facets/aws_cloud_account`
- **Provides:** AWS provider configuration
- **Required Fields:**
  - `aws_region`
  - `aws_account_id`
  - `aws_iam_role`

### 2. VPC Network
- **Type:** `@facets/aws_vpc`
- **Provides:** VPC and subnet configuration
- **Required Fields:**
  - `vpc_id`
  - `private_subnet_ids` (list)
  - `public_subnet_ids` (optional list)

## Outputs

This module exposes the following outputs:

### Attributes
- `cluster_id` - The EKS cluster ID
- `cluster_arn` - The EKS cluster ARN
- `cluster_name` - The EKS cluster name
- `cluster_version` - The Kubernetes version
- `cluster_endpoint` - The EKS cluster API endpoint
- `cluster_ca_certificate` - The cluster CA certificate (base64 decoded)
- `cluster_token` - Authentication token (marked as secret)
- `cluster_security_group_id` - The cluster security group ID
- `node_security_group_id` - The node security group ID
- `oidc_provider_arn` - The OIDC provider ARN for IRSA
- `cluster_iam_role_arn` - The cluster IAM role ARN
- `cluster_primary_security_group_id` - The primary security group ID

### Providers Exposed
- **Kubernetes Provider** (hashicorp/kubernetes v2.23.0)
- **Helm Provider** (hashicorp/helm v2.11.0)

## Configuration Schema

### Basic Configuration

```yaml
spec:
  cluster_version: "1.30"  # Kubernetes version: 1.28, 1.29, 1.30, 1.31
  cluster_endpoint_public_access: true   # Enable public API access
  cluster_endpoint_private_access: true  # Enable private API access
  enable_cluster_encryption: false       # Enable KMS secrets encryption
```

### Managed Node Groups

Configure one or more managed node groups using a map structure:

```yaml
spec:
  managed_node_groups:
    general:  # Node group name
      instance_types: ["t3.medium", "t3.large"]
      min_size: 1
      max_size: 10
      desired_size: 3
      capacity_type: "ON_DEMAND"  # or "SPOT"
      disk_size: 50
      labels:
        workload-type: general
        environment: production
      taints:
        dedicated: general  # Applied with NoSchedule effect

    spot-workers:  # Another node group
      instance_types: ["t3.xlarge"]
      min_size: 0
      max_size: 20
      desired_size: 5
      capacity_type: "SPOT"
      disk_size: 100
      labels:
        workload-type: batch
```

### Cluster Add-ons

```yaml
spec:
  cluster_addons:
    vpc_cni:
      enabled: true
      version: "latest"  # or specific version like "v1.12.0-eksbuild.1"
    kube_proxy:
      enabled: true
      version: "latest"
    coredns:
      enabled: true
      version: "latest"
```

### Cluster Tags

```yaml
spec:
  cluster_tags:
    Team: platform
    CostCenter: engineering
```

## Example Blueprint Resource

```yaml
kind: kubernetes_cluster
flavor: eks_standard
version: "1.0"
metadata:
  name: my-eks-cluster
disabled: false
spec:
  cluster_version: "1.30"
  cluster_endpoint_public_access: true
  cluster_endpoint_private_access: true
  enable_cluster_encryption: true

  cluster_addons:
    vpc_cni:
      enabled: true
      version: "latest"
    kube_proxy:
      enabled: true
      version: "latest"
    coredns:
      enabled: true
      version: "latest"

  managed_node_groups:
    system:
      instance_types: ["t3.medium"]
      min_size: 2
      max_size: 4
      desired_size: 2
      capacity_type: "ON_DEMAND"
      disk_size: 50
      labels:
        node-type: system

    application:
      instance_types: ["t3.large", "t3.xlarge"]
      min_size: 3
      max_size: 20
      desired_size: 5
      capacity_type: "ON_DEMAND"
      disk_size: 100
      labels:
        node-type: application

  cluster_tags:
    Environment: production
    ManagedBy: facets
```

## Important Notes

### 1. EKS Auto Mode
**This module explicitly does NOT support EKS Auto Mode.** The module is designed for the standard EKS deployment model with managed node groups. If you need EKS Auto Mode capabilities, you should create a separate module with flavor `eks_auto`.

### 2. Node Group Deployment
- All node groups are deployed in the **private subnets** from the VPC input
- Node groups are managed by AWS EKS (fully managed lifecycle)
- Each node group can have different instance types, scaling configurations, and Kubernetes labels/taints

### 3. Security
- The module creates a KMS key for secrets encryption when `enable_cluster_encryption: true`
- The KMS key has automatic rotation enabled
- The cluster authentication token is marked as a secret in outputs

### 4. Networking
- The cluster is deployed across the subnets provided by the VPC network input
- Both public and private subnets (if provided) are used for the control plane
- Worker nodes are always deployed in private subnets

### 5. Taints
- Taints specified in the node group configuration are applied with the `NoSchedule` effect
- Format: `key: value` pairs in the YAML

## Module Structure

```
eks_standard_module/
├── facets.yaml       # Module metadata and schema
├── variables.tf      # Input variable definitions
├── main.tf           # Main Terraform resources
├── outputs.tf        # Output definitions (locals only)
├── versions.tf       # Terraform version constraints
└── README.md         # This file
```

## Deployment Workflow

1. **Upload Module** (Preview stage for testing):
   ```bash
   raptor create iac-module -f ./eks_standard_module --auto-create
   ```

2. **Test in Testing Project**:
   - Add a resource using this module to your blueprint
   - Run a plan to validate configuration
   - Deploy to test environment

3. **Publish** (when ready):
   ```bash
   raptor publish iac-module kubernetes_cluster/eks_standard/1.0
   ```

## Design Decisions

### Why Maps Instead of Arrays for Node Groups?
The module uses maps (patternProperties) for node groups instead of arrays because:
- **Deep merge support**: Environment overrides can modify individual node groups without repeating the entire configuration
- **Stable identifiers**: Node group names serve as keys for clear identification
- **Better maintainability**: Easier to override specific node groups per environment

### Why No Provider Blocks?
Following Facets conventions:
- Providers are passed from input modules (cloud_account)
- Provider versions are defined in output type schemas
- This ensures consistent provider configuration across modules

### Why Local Outputs?
Facets automatically extracts outputs from `local.output_attributes` and `local.output_interfaces`:
- No Terraform `output` blocks needed
- Consistent with Facets platform patterns
- Separates infrastructure outputs (attributes) from network endpoints (interfaces)

## Terraform Compatibility

- **Terraform Version**: >= 1.5.0, < 2.0.0
- **terraform-aws-eks Module**: ~> 20.0

## Support

For issues or questions about this module:
1. Check the Facets platform documentation
2. Review the terraform-aws-eks module documentation: https://github.com/terraform-aws-modules/terraform-aws-eks
3. Contact your platform team
