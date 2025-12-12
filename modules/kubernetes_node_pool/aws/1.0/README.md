# AWS EKS Auto Mode Karpenter NodePool Module

## Overview

The EKS Auto Mode Karpenter NodePool module creates and manages dynamic node pools for EKS Auto Mode clusters with intelligent scaling and cost optimization. This module leverages AWS Karpenter for automatic node provisioning based on workload requirements, supporting both Spot and On-Demand instances with advanced scheduling and consolidation policies.

## Configurability

- **Instance Requirements**: Define flexible compute resources with multiple classification methods:
  - Instance Category: Broad categorization (c, m, r, g families)
  - Instance Family: Specific EC2 families (t3, m5, c6g, r5b)
  - Instance Types: Precise instance type selection (m6i.large, c5.xlarge)
- **Scaling Configuration**: Intelligent resource management with:
  - CPU and memory limits with Kubernetes resource quantity validation
  - Cost optimization through node consolidation policies
  - Configurable consolidation delays and thresholds
- **Storage Configuration**: Advanced storage options including:
  - Disk size, IOPS, and throughput configuration
  - KMS encryption key support for enhanced security
  - EBS-optimized storage with performance tuning
- **Workload Scheduling**: Fine-grained pod placement control with:
  - Node labels for workload targeting
  - Taint configuration for workload isolation
  - Support for specialized workloads (GPU, high-memory, etc.)
- **Multi-Architecture Support**: Both AMD64 and ARM64 instance support
- **Capacity Types**: Flexible instance sourcing with Spot and On-Demand options
- **Validation & UI Enhancements**:
  - Pattern validation for instance types, CPU ranges, and resource quantities
  - YAML editor for complex taint and label configurations
  - Dynamic validation for availability zones and capacity types

## Usage

This module is designed for dynamic, cost-optimized Kubernetes workloads on AWS EKS Auto Mode clusters.

Common use cases:

- Running cost-optimized workloads with intelligent Spot instance utilization
- Supporting diverse compute requirements with flexible instance type selection
- Implementing workload isolation through advanced taint and label management
- Optimizing costs through intelligent node consolidation and scaling policies
- Supporting multi-architecture workloads with AMD64 and ARM64 instances
- Managing specialized workloads requiring specific instance types or storage configurations