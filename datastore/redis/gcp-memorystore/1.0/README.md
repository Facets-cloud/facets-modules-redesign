# GCP Redis Memorystore Module

[![Terraform](https://img.shields.io/badge/terraform-1.5.7-blue.svg)](https://www.terraform.io/downloads.html)
[![GCP](https://img.shields.io/badge/gcp-memorystore-orange.svg)](https://cloud.google.com/memorystore)

## Overview

This module creates a managed Redis instance using Google Cloud Memorystore with high availability and security features. It integrates seamlessly with existing VPC networks and private service connections managed by the network module.

The module supports both Basic and Standard HA tiers with automatic encryption, authentication, and backup capabilities. It's designed to use existing network infrastructure without creating additional private connections or IP ranges.

## Environment as Dimension

**Environment-aware networking**: The module scales with your environment by leveraging existing network infrastructure. Different environments will use their respective VPC networks and private service connections as configured by the network module. This ensures proper network isolation and security across development, staging, and production environments.

The instance naming includes the environment's unique identifier to prevent conflicts and enable proper resource tracking across multiple environments.

## Resources Created

- **Redis Memorystore Instance**: Managed Redis instance with configurable memory size and service tier
- **Authentication Configuration**: Automatic generation of secure auth tokens for Redis access
- **High Availability Setup**: Optional read replicas and regional distribution for Standard HA tier
- **Security Features**: Transit encryption and authentication enabled by default
- **Network Integration**: Private network access using existing VPC and private service connections

## Security Considerations

This module implements security-first defaults that cannot be overridden:

- **Private Network Access**: All instances use private IPs and existing VPC private service connections
- **Authentication Required**: Auth tokens are automatically generated and enforced
- **Transit Encryption**: Server-side authentication for encrypted connections
- **No Public Access**: Instances are only accessible from within the configured VPC network
- **Lifecycle Protection**: Resources include prevent_destroy configuration to avoid accidental data loss

**Network Dependencies**: This module requires a properly configured VPC network with private service access enabled. The network module must provide the private services connection and IP ranges before Redis instances can be created.

**Backup Strategy**: Memorystore provides automatic backup capabilities through GCP's infrastructure. Point-in-time recovery and backup restoration should be managed through Google Cloud Console or gcloud CLI rather than Terraform configuration.