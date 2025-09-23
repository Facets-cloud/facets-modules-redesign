# Azure Virtual Network Module - Simplified

[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/azure-%230072C6.svg?style=for-the-badge&logo=microsoftazure&logoColor=white)](https://azure.microsoft.com/)

## Overview

This module creates a simplified Azure Virtual Network with fixed subnet allocation from a `/16` CIDR range. It automatically provisions one public subnet and one private subnet per availability zone with optimized IP address allocation for typical workloads.

The module eliminates configuration complexity by using intelligent defaults while providing the essential network infrastructure needed for most Azure deployments.

## Environment as Dimension

**Environment awareness:** This module adapts to different environments through:

- **Region variation**: Different Azure regions per environment (dev in East US, prod in West Europe)
- **Availability zones**: Environment-specific AZ configurations based on regional availability  
- **AKS integration**: Can be enabled for environments that require Kubernetes workloads
- **NAT gateway strategy**: Single gateway for dev environments, per-AZ for production environments
- **Resource tagging**: Environment-specific tags for cost allocation and resource management

## Fixed Subnet Allocation

The module automatically creates a simplified network topology:

- **Public Subnets**: `/24` subnets (256 IPs each) - one per availability zone
- **Private Subnets**: `/18` subnets (16,384 IPs each) - one per availability zone

This allocation provides:
- Sufficient IP space for typical workloads in private subnets
- Cost-effective public subnet sizing for load balancers and gateways
- Automatic CIDR calculation to prevent IP address conflicts
- Optimal resource distribution across availability zones

## Resources Created

- **Virtual Network**: Main network container with `/16` CIDR
- **Public Subnets**: Internet-facing subnets for load balancers and public resources
- **Private Subnets**: Internal application subnets with NAT gateway connectivity
- **Resource Group**: Container for all network resources
- **NAT Gateways**: Outbound internet connectivity for private subnets (single or per-AZ)
- **Network Security Groups**: Basic security groups allowing VNet-internal traffic
- **Route Tables**: Custom routing for public and private subnet traffic management

## Security Considerations

This module implements essential security practices:

- **Private subnets** use NAT gateways for outbound internet access without exposing resources to inbound traffic
- **Network Security Groups** provide basic traffic filtering with VNet-internal access allowed by default
- **AKS delegation** is automatically configured on private subnets when AKS integration is enabled
- **Route tables** ensure proper traffic flow between subnets and internet gateways

Users should customize security group rules based on their specific security requirements and add additional network policies as needed for their workloads.
