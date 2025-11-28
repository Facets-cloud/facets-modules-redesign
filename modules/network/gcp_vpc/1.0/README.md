# GCP VPC Network Module

## Overview

This module creates a comprehensive Google Cloud Platform (GCP) Virtual Private Cloud (VPC) network infrastructure with configurable public, private, and database subnets distributed across multiple zones. It provides a robust foundation for deploying applications and databases in GCP with proper network segmentation and security controls.

## Environment as Dimension

The module is environment-aware and adapts to different deployment contexts:

- **CIDR Block**: VPC CIDR is typically overridden per environment to prevent conflicts (dev: 10.1.0.0/16, staging: 10.2.0.0/16, prod: 10.0.0.0/16)
- **Zone Selection**: Zones can be auto-selected or explicitly defined per environment based on regional availability and requirements
- **NAT Strategy**: Production environments often use per-zone NAT for high availability, while development may use single NAT for cost optimization
- **Firewall Rules**: Security policies may vary between environments (stricter in production, more permissive in development)

## Resources Created

- **VPC Network**: A custom VPC with regional routing and no auto-created subnetworks
- **Subnetworks**: Configurable public, private, and database subnets across selected zones
- **Cloud Router**: Regional routers for managing NAT gateways and routing
- **Cloud NAT**: NAT gateways for outbound internet access from private subnets (single or per-zone strategy)
- **Firewall Rules**: Configurable security rules for internal traffic, SSH, HTTP/HTTPS, and ICMP
- **Private Google Access**: Enabled on private and database subnets for accessing Google APIs without external IPs

## Security Considerations

The module implements several security best practices:

- **Network Segmentation**: Separate subnets for public-facing resources, private application tiers, and database layers
- **Private Google Access**: Database and private subnets can access Google Cloud services without requiring external IP addresses
- **Firewall Rules**: Conditional firewall rules with network tags for granular access control
- **Default Deny**: Only explicitly allowed traffic is permitted through firewall rules
- **NAT Gateway Logging**: Cloud NAT logging enabled for security monitoring and troubleshooting

Instances deployed in private and database subnets have no direct internet access, requiring NAT gateway for outbound connections. This prevents unauthorized inbound access while maintaining necessary outbound connectivity for updates and API calls.
