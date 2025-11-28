# AWS Cloud Account Module

## Overview

The AWS Cloud Account module configures and provisions resources within an AWS cloud account. This module establishes the foundational connection to AWS services, enabling secure access and resource management across your infrastructure. It provides essential cloud account configuration including region selection, IAM role management, and provider authentication.

## Configurability

- **Cloud Account Selection**: Choose from previously linked AWS cloud accounts with automatic validation and filtering.
- **Region Configuration**: Select AWS regions with dynamic dropdown populated from AWS API.
- **IAM Role Management**: Configure cross-account access with assume role capabilities including session names and external IDs.
- **Provider Authentication**: Secure AWS provider configuration with role-based access control.
- **Validation & UI Enhancements**:
  - Dynamic region selection with real-time AWS API integration
  - Cloud account filtering by provider type (AWS only)
  - Integrated validation for IAM role ARNs and session configurations

## Usage

This module is designed as the foundational component for all AWS-based infrastructure deployments.

Common use cases:

- Establishing secure AWS cloud account connections for infrastructure provisioning
- Configuring cross-account access patterns for multi-account AWS environments
- Setting up regional deployments with proper IAM role assumptions
- Enabling secure provider authentication for Terraform-based resource management
- Supporting enterprise-grade AWS access control and compliance requirements
