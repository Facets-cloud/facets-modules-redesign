# AWS EKS Cluster Module

## Overview

The EKS (Elastic Kubernetes Service) module provisions a fully managed Kubernetes cluster on AWS with auto mode support and comprehensive addon management. This module creates production-ready EKS clusters with intelligent node management, security configurations, and integrated AWS services. It supports both public and private cluster endpoints with flexible networking and logging options.

## Configurability

- **Cluster Endpoint Access**: Configure public/private API server access with CIDR-based restrictions for enhanced security.
- **CloudWatch Logging**: Enable comprehensive logging with configurable retention periods and log types (API, audit, authenticator).
- **EKS Cluster Addons**: Install and configure essential AWS addons including:
  - CSI drivers (EFS, FSx, S3)
  - Security and monitoring agents (GuardDuty, CloudWatch Observability)
  - Network flow monitoring and observability tools
  - SageMaker HyperPod components for ML workloads
- **Addon Configuration**: Fine-grained control over addon settings including:
  - Service account role ARNs for secure permissions
  - Custom configuration values via YAML editor
  - Individual addon enable/disable controls
- **Validation & UI Enhancements**:
  - Dynamic addon selection with comprehensive AWS addon catalog
  - YAML-based configuration for complex addon settings
  - Integrated validation for IAM roles and service account bindings

## Usage

This module is designed for production Kubernetes workloads on AWS, providing enterprise-grade cluster management.

Common use cases:

- Deploying production-ready Kubernetes clusters with AWS best practices
- Setting up secure, multi-tenant Kubernetes environments with proper IAM integration
- Enabling comprehensive observability and monitoring with AWS native services
- Supporting machine learning workloads with SageMaker HyperPod integration
- Implementing secure cluster access patterns with private endpoints and CIDR restrictions
- Managing complex addon configurations for specialized workloads and compliance requirements