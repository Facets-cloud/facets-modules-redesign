# Azure AKS Node Pool Module

## Overview

The Azure AKS Node Pool module creates and manages custom node pools for Azure Kubernetes Service clusters with intelligent scaling and workload isolation capabilities. This module provides flexible node pool management with support for various Azure VM sizes, advanced taint configurations, and comprehensive labeling strategies for workload targeting and resource optimization.

## Configurability

- **Instance Configuration**: 
  - Flexible Azure VM size selection (e.g., Standard_F8, Standard_D4a_v4)
  - Comprehensive instance type validation and placeholder guidance
  - Support for various Azure VM families and performance tiers
- **Scaling Management**: Intelligent node pool scaling with:
  - Minimum and maximum node count configuration (0-100 nodes)
  - Auto-scaling capabilities for dynamic workload management
  - Resource optimization through flexible scaling policies
- **Storage Configuration**: Advanced disk management including:
  - Disk size configuration (50G to 1000G) with pattern validation
  - Support for various Azure disk types and performance tiers
  - Optimized storage allocation for different workload requirements
- **Workload Isolation**: Sophisticated taint and label management:
  - Custom taint configuration with key-value-effect patterns
  - Node label management for workload targeting
  - Support for specialized workloads requiring node isolation
- **Validation & UI Enhancements**:
  - Pattern validation for disk sizes, taint keys, and node counts
  - YAML editor for complex taint and label configurations
  - Comprehensive error messaging with format examples
  - Dynamic validation for Azure VM size compatibility

## Usage

This module is designed for dynamic, workload-specific node pool management on Azure AKS clusters.

Common use cases:

- Creating specialized node pools for different workload types (compute-intensive, memory-optimized, GPU workloads)
- Implementing workload isolation through advanced taint and label management
- Supporting diverse compute requirements with flexible Azure VM size selection
- Managing cost optimization through intelligent node pool scaling
- Enabling specialized workloads requiring specific node configurations or isolation
- Supporting enterprise compliance requirements with granular node pool management