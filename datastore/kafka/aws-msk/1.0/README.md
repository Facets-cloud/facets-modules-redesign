# AWS MSK Kafka Cluster Module

[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](.)

## Overview

This module creates an AWS Managed Streaming for Apache Kafka (MSK) cluster with secure defaults and automatic scaling capabilities. It provides a production-ready Kafka environment with encryption, monitoring, and high availability features.

## Environment as Dimension

This module is environment-aware and configures resources based on the target environment:

- **Cluster naming**: Incorporates environment unique names to ensure global uniqueness across environments
- **Tagging strategy**: Applies environment-specific cloud tags for resource management and cost allocation
- **Security configuration**: Uses environment-appropriate VPC and subnet configurations
- **Monitoring**: Environment-specific log groups and monitoring configurations

## Resources Created

This module creates the following AWS resources:

- **MSK Cluster**: The core Kafka cluster with configured broker nodes across multiple availability zones
- **KMS Key and Alias**: For encryption at rest of Kafka data and logs
- **Security Group**: Controls network access to the MSK cluster with appropriate ingress and egress rules
- **MSK Configuration**: Custom Kafka configuration with production-ready settings
- **CloudWatch Log Group**: For centralized logging of Kafka broker activities
- **IAM Roles and Policies**: For cluster operations and client authentication (when applicable)

## Security Considerations

This module implements several security best practices:

- **Encryption at Rest**: All data is encrypted using AWS KMS with customer-managed keys
- **Encryption in Transit**: TLS encryption is enforced for all client-broker and inter-broker communication
- **Network Security**: Restrictive security groups limit access to VPC CIDR blocks only
- **Access Control**: Supports IAM-based authentication and SASL/SCRAM mechanisms
- **Monitoring**: Comprehensive logging and monitoring capabilities for security auditing
- **Lifecycle Protection**: Critical resources are protected from accidental deletion

The module follows AWS security best practices and is suitable for production workloads requiring high security standards.
