# Azure Cloud Account Module

## Overview

The Azure Cloud Account module configures and provisions resources within an Azure cloud account. This module establishes the foundational connection to Azure services, enabling secure access and resource management across your infrastructure. It provides essential cloud account configuration including subscription management, service principal authentication, and provider setup for both Azure Resource Manager and Azure API providers.

## Configurability

- **Cloud Account Selection**: Choose from previously linked Azure cloud accounts with automatic validation and filtering by provider type.
- **Multi-Provider Support**: Configure both Azure Resource Manager (azurerm) and Azure API (azapi) providers for comprehensive Azure service access.
- **Service Principal Authentication**: Secure Azure provider configuration with client ID, client secret, tenant ID, and subscription ID management.
- **Provider Version Management**: Automatic provider version management with Azure Resource Manager 4.36.0 and Azure API 2.5.0.
- **Validation & UI Enhancements**:
  - Cloud account filtering by provider type (Azure only)
  - Integrated validation for Azure service principal credentials
  - Dynamic account selection with real-time validation

## Usage

This module is designed as the foundational component for all Azure-based infrastructure deployments.

Common use cases:

- Establishing secure Azure cloud account connections for infrastructure provisioning
- Configuring multi-subscription access patterns for enterprise Azure environments
- Setting up service principal authentication for automated resource management
- Enabling secure provider authentication for Terraform-based Azure resource management
- Supporting enterprise-grade Azure access control and compliance requirements
