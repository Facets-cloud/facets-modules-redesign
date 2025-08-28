# Azure Cache for Redis

This Terraform module provisions Azure Cache for Redis, a fully managed in-memory data structure service built on open-source Redis. The module provides high-performance caching with built-in security, scalability, and reliability features for Azure applications.

## Overview

Azure Cache for Redis delivers sub-millisecond response times for high-throughput, low-latency workloads. This module simplifies Redis deployment with developer-friendly configuration options while maintaining production-ready security defaults and operational best practices.

## Environment as Dimension

The module creates environment-specific cache instances by incorporating the environment's unique name into the cache identifier. This ensures proper isolation between development, staging, and production environments. Cache configurations, network settings, and backup policies can vary per environment while maintaining consistent security postures across all deployments.

## Resources Created

- **Azure Cache for Redis**: Main cache instance with specified performance tier and capacity
- **Network Integration**: VNet subnet association for secure private network access  
- **Firewall Rules**: Automatic security rules allowing access from specified subnet ranges
- **Backup Configuration**: Automated daily backups with 7-day retention (Premium tier)
- **SSL/TLS Encryption**: Secure connections with TLS 1.2+ enforcement
- **Authentication**: Primary and secondary access keys for client authentication
- **Monitoring Integration**: Built-in metrics and diagnostics for cache performance

## Security Considerations

The module implements security-first defaults including TLS-only connections, private network deployment within VNet subnets, and firewall rules restricting access to authorized network ranges. Non-SSL ports are disabled by default to prevent unencrypted connections. Access keys are automatically generated and rotated through Azure's key management system.
