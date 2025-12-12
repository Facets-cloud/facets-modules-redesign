# AWS VPC Network Module

## Overview

The AWS VPC module creates a Kubernetes-optimized Virtual Private Cloud with auto-calculated subnets across availability zones. This module provides a production-ready network foundation with fixed IP allocation patterns optimized for Kubernetes workloads, including private, public, and database subnets with comprehensive VPC endpoint support.

## Configurability

- **VPC Configuration**: 
  - Fixed /16 CIDR block allocation optimized for Kubernetes workloads
  - Automatic availability zone selection (3 AZs) or manual specification (2-5 AZs)
  - Pre-calculated subnet allocations: Private (8K IPs/AZ), Public (256 IPs/AZ), Database (256 IPs/AZ)
- **NAT Gateway Strategy**: Choose between single NAT Gateway for cost optimization or per-AZ NAT Gateways for high availability
- **VPC Endpoints**: Comprehensive AWS service endpoint configuration including:
  - **Gateway Endpoints** (no additional charges): S3, DynamoDB
  - **Interface Endpoints** (charges apply): ECR API/Docker, EKS, EC2, SSM, KMS, CloudWatch, STS, Lambda
  - Cost-optimized defaults with optional premium endpoints
- **Network Security**: Built-in security groups and NACLs optimized for Kubernetes traffic patterns
- **Validation & UI Enhancements**:
  - CIDR block validation ensuring /16 allocation
  - Availability zone count validation (2-5 AZs)
  - Toggle-based endpoint configuration with cost awareness
  - YAML editor for custom tagging and advanced configurations

## Usage

This module is designed as the foundational network layer for Kubernetes workloads on AWS.

Common use cases:

- Creating secure, isolated network environments for Kubernetes clusters
- Implementing cost-optimized networking with strategic VPC endpoint placement
- Supporting multi-AZ deployments with proper subnet allocation for high availability
- Enabling secure container registry access with ECR VPC endpoints
- Reducing data transfer costs through strategic VPC endpoint configuration
- Supporting enterprise compliance requirements with private networking and endpoint security