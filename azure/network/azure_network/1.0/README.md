# Azure Virtual Network Module

## Overview

The Azure Virtual Network module creates a comprehensive Azure Virtual Network with automatically calculated subnet sizes and specialized database networking support. This module provides production-ready network infrastructure with dedicated database subnets, NAT gateway management, and advanced networking features optimized for Azure services including PostgreSQL and MySQL Flexible Servers.

## Configurability

- **VNet Configuration**: 
  - Fixed /16 CIDR block allocation optimized for Azure workloads
  - Automatic availability zone selection (1-3 AZs) with flexible configuration
  - Comprehensive subnet allocation with automatic size calculation
- **Database Networking**: Specialized database subnet configuration including:
  - General database subnet for private endpoints and non-delegated resources
  - PostgreSQL Flexible Server subnet with proper delegation
  - MySQL Flexible Server subnet with dedicated networking
  - Automatic /24 block allocation for database subnets
- **NAT Gateway Management**: Flexible NAT gateway strategies:
  - Single NAT Gateway for cost optimization
  - Per-AZ NAT Gateway for high availability scenarios
  - Comprehensive outbound connectivity management
- **Advanced Networking Features**:
  - DNS zone integration for Azure services
  - Security group configuration optimized for Kubernetes
  - Routing table management for complex network topologies
- **Validation & UI Enhancements**:
  - CIDR block validation ensuring /16 allocation
  - Availability zone count validation (1-3 AZs)
  - Toggle-based database subnet configuration
  - YAML editor for custom tagging and advanced configurations

## Usage

This module is designed as the foundational network layer for Azure workloads with specialized database support.

Common use cases:

- Creating secure, isolated network environments for Azure Kubernetes Service clusters
- Implementing database-focused networking with PostgreSQL and MySQL Flexible Server support
- Setting up cost-optimized networking with strategic NAT gateway placement
- Supporting multi-AZ deployments with proper subnet allocation for high availability
- Enabling specialized database workloads with dedicated networking configurations
- Supporting enterprise compliance requirements with private networking and database isolation