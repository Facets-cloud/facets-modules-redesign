# Linode VPC Network

Creates a Linode VPC with a primary subnet for Kubernetes nodes and managed services. Produces the `@facets/linode-vpc-details` output type.

## Overview

This module provisions a Linode VPC and a single primary subnet in the chosen region. The VPC and subnet provide private, segmented connectivity for LKE node pools, Linode instances, and managed databases. The region defaults to the cloud account's default region when not overridden.

## Resources Created

- **linode_vpc**: The VPC container, scoped to a single region
- **linode_vpc_subnet**: The primary subnet (CIDR configurable via spec)

## Required Configuration

- **Subnet CIDR**: CIDR block for the primary subnet (default `10.0.0.0/24`)
- **Region** (optional): Linode region; defaults to the cloud account region

## Inputs

- **Linode Cloud Account** (`@facets/linode_cloud_account`): provides the Linode provider and default region

## Outputs

- `@facets/linode-vpc-details`: `vpc_id`, `vpc_label`, `region`, `subnet_id`, `subnet_label`, `subnet_cidr`
