# Azure AKS Cluster Module

## Overview

The AKS (Azure Kubernetes Service) module provisions a fully managed Kubernetes cluster on Azure with comprehensive auto-upgrade support and intelligent maintenance window management. This module creates production-ready AKS clusters with advanced upgrade strategies, flexible node pool configurations, and integrated Azure services. It supports both Free and Standard SKU tiers with sophisticated maintenance scheduling.

## Configurability

- **Cluster Configuration**: 
  - SKU tier selection (Free or Standard) for different service levels
  - Public endpoint access with CIDR-based restrictions for enhanced security
  - Comprehensive cluster endpoint management
- **Auto-Upgrade Management**: Intelligent cluster version management with:
  - Multiple upgrade channels: rapid, regular, stable, patch, node-image
  - Configurable max surge settings for rolling upgrades
  - Advanced maintenance window scheduling with multiple frequency options
- **Maintenance Windows**: Sophisticated scheduling system including:
  - Daily, Weekly, AbsoluteMonthly, and RelativeMonthly frequencies
  - Configurable intervals, days of week, and time windows
  - Week index selection for relative monthly scheduling
  - Start and end time configuration for maintenance windows
- **Node Pool Management**: Comprehensive system node pool configuration with:
  - Instance type selection and node count management
  - Auto-scaling capabilities with min/max node settings
  - OS disk size configuration and max pods per node
  - Custom node labels and Kubernetes integration
- **Validation & UI Enhancements**:
  - Pattern validation for max surge settings and maintenance intervals
  - YAML editor for complex node label configurations
  - Dynamic visibility controls for maintenance window settings
  - Comprehensive error messaging and validation feedback

## Usage

This module is designed for production Kubernetes workloads on Azure with enterprise-grade upgrade management.

Common use cases:

- Deploying production-ready Kubernetes clusters with automated upgrade management
- Setting up secure, multi-tenant Kubernetes environments with proper Azure integration
- Implementing sophisticated maintenance windows for enterprise compliance requirements
- Managing cluster upgrades with minimal downtime through intelligent surge configuration
- Supporting diverse workload requirements with flexible node pool configurations
- Enabling enterprise-grade cluster management with comprehensive monitoring and maintenance scheduling