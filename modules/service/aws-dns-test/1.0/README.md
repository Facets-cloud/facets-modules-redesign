# AWS Cloud Service Module

## Overview

The AWS Cloud Service module provides a unified platform for deploying and managing Kubernetes workloads on AWS with comprehensive support for applications, cronjobs, jobs, and statefulsets. This module integrates advanced workload management features including autoscaling, health checks, volume management, and AWS-specific permissions through IRSA (IAM Roles for Service Accounts).

## Configurability

- **Workload Types**: Support for multiple Kubernetes workload patterns:
  - **Applications**: Long-running services with autoscaling and health checks
  - **CronJobs**: Scheduled tasks with flexible cron expressions and concurrency policies
  - **Jobs**: One-time and batch processing with retry mechanisms
  - **StatefulSets**: Stateful applications with persistent volume claims
- **Advanced Scheduling**: Sophisticated pod placement and distribution:
  - Host anti-affinity for high availability
  - Topology spread constraints for optimal distribution
  - Node affinity and taint policies for workload isolation
- **Resource Management**: Comprehensive resource configuration:
  - CPU and memory requests/limits with validation
  - Autoscaling based on CPU or memory thresholds
  - Persistent volume claims with flexible access modes
- **Health Monitoring**: Multi-layered health check system:
  - Readiness, liveness, and startup probes
  - HTTP, TCP, and exec-based health checks
  - Configurable timeouts, intervals, and startup delays
- **AWS Integration**: Native AWS service integration:
  - IRSA (IAM Roles for Service Accounts) for secure AWS API access
  - Custom IAM policies for fine-grained permissions
  - Container registry integration with artifact management
- **Volume Management**: Flexible storage options:
  - ConfigMaps, Secrets, PVCs, and host path mounts
  - Support for init containers and sidecar containers
  - Advanced volume configuration with sub-path mounting
- **Validation & UI Enhancements**:
  - Pattern validation for resource quantities, ports, and paths
  - Dynamic dropdowns for resource discovery and selection
  - YAML editors for complex configurations
  - Comprehensive error messaging and validation feedback

## Usage

This module is designed for production-grade Kubernetes workload deployment on AWS with enterprise features.

Common use cases:

- Deploying microservices with advanced autoscaling and health monitoring
- Running scheduled batch processing jobs with retry mechanisms and resource optimization
- Managing stateful applications with persistent storage and backup strategies
- Implementing secure AWS service integration through IRSA and custom IAM policies
- Supporting complex multi-container applications with init and sidecar containers
- Enabling enterprise-grade workload management with comprehensive monitoring and resource optimization