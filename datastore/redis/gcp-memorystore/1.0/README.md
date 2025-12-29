# GCP Redis Memorystore Module

[![Terraform](https://img.shields.io/badge/terraform-1.5.7-blue.svg)](https://www.terraform.io/downloads.html)
[![GCP](https://img.shields.io/badge/gcp-memorystore-orange.svg)](https://cloud.google.com/memorystore)

## Overview

This module creates a managed Redis instance using Google Cloud Memorystore with high availability and security features. It requires integration with a VPC network module that provides private service access connectivity.

The module supports both Basic and Standard HA tiers with configurable TLS encryption, automatic authentication, and backup capabilities. It uses existing network infrastructure from the required network module for secure, private connectivity.

## Environment as Dimension

**Environment-aware networking**: The module scales with your environment by leveraging existing network infrastructure. Different environments will use their respective VPC networks and private service connections as configured by the network module. This ensures proper network isolation and security across development, staging, and production environments.

The instance naming includes the environment's unique identifier to prevent conflicts and enable proper resource tracking across multiple environments.

## Resources Created

- **Redis Memorystore Instance**: Managed Redis instance with configurable memory size and service tier
- **Authentication Configuration**: Automatic generation of secure auth tokens for Redis access
- **High Availability Setup**: Optional read replicas and regional distribution for Standard HA tier
- **Security Features**: Configurable TLS transit encryption and authentication always enabled
- **Network Integration**: Private network access using required VPC network module with private service connections

## Security Considerations

This module implements security-first defaults:

- **Private Network Access**: All instances use private IPs with VPC private service connections (required)
- **Authentication Required**: Auth tokens are automatically generated and always enforced
- **Transit Encryption (TLS)**: Configurable TLS encryption with server authentication (enabled by default)
- **No Public Access**: Instances are only accessible from within the configured VPC network
- **Lifecycle Protection**: Resources include prevent_destroy configuration to avoid accidental data loss

**Network Dependencies**: This module **requires** a VPC network module that provides private service access connectivity. The network input is mandatory and must include:
- VPC self-link for authorized network access
- Private service connection configuration
- Region and network details

**Backup Strategy**: Memorystore provides automatic backup capabilities through GCP's infrastructure. Point-in-time recovery and backup restoration should be managed through Google Cloud Console or gcloud CLI rather than Terraform configuration.

## Configuration

### Redis Versions

Supported Redis versions (as per [GCP Memorystore documentation](https://cloud.google.com/memorystore/docs/redis/supported-versions)):
- `REDIS_7_2` - Latest version
- `REDIS_7_0` - **Default** (matches GCP default)
- `REDIS_6_X` - Stable version
- `REDIS_5_0` - Legacy support

### Service Tiers

- **BASIC**: Standalone instance for development/testing
- **STANDARD_HA**: Highly available primary/replica instances for production (requires minimum 5GB memory)

### Security Options

- **TLS Encryption**: Enable/disable transit encryption via `enable_tls` boolean (default: `true`)
  - When enabled: Uses SERVER_AUTHENTICATION mode
  - When disabled: No transit encryption (not recommended for production)

### Network Requirements

The network module must provide:
- VPC self-link for authorized network
- Private service access connection
- Region configuration
- Private services connection details