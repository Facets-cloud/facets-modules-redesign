# GCP VPC Network Module

![Status: Stable](https://img.shields.io/badge/status-stable-green.svg)

## Overview

Creates a comprehensive GCP VPC network with configurable public, private, and database subnets distributed across multiple availability zones. The module includes Cloud NAT gateways, firewall rules, and private services connectivity to support a complete network infrastructure.

The module supports flexible subnet configuration per zone and automatically handles CIDR allocation to prevent overlaps.

## Environment as Dimension

This module is environment-aware through:
- **Region selection**: Different environments can use different GCP regions
- **CIDR blocks**: VPC and private services CIDR ranges must be unique per environment
- **Zone configuration**: Zones can be auto-selected or manually specified per environment
- **Subnet sizing**: Different environments can have different subnet configurations based on scale requirements

## Resources Created

- **VPC Network**: Primary network container with regional routing
- **Subnets**: Public, private, and database subnets across selected zones with configurable CIDR ranges
- **Cloud Routers**: Regional routers to support Cloud NAT functionality
- **Cloud NAT Gateways**: Either single or per-zone NAT for outbound internet connectivity from private resources
- **Firewall Rules**: Configurable rules for internal traffic, SSH, HTTP/HTTPS, and ICMP
- **Private Services Connection**: Global address reservation and service networking connection for managed services like Cloud SQL
- **Private Google Access**: Configured on private and database subnets for accessing Google APIs without external IPs

## Security Considerations

The module implements defense-in-depth networking patterns:

**Network Segmentation**: Three distinct subnet types (public, private, database) provide clear separation of concerns and limit blast radius.

**Private Services Connectivity**: Database subnets use private services connection instead of public IPs, ensuring sensitive data never traverses the public internet.

**Controlled Internet Access**: Private subnets access the internet only through Cloud NAT, preventing direct inbound connections while enabling outbound connectivity.

**Granular Firewall Controls**: All firewall rules are optional and can be disabled. SSH access requires specific network tags, preventing accidental exposure.

Users should review firewall rule configuration and ensure proper network tags are applied to instances based on their access requirements.
