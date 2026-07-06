# Vultr VPC Network

Creates a Vultr (legacy) VPC private network for Kubernetes nodes and managed services. Produces `@facets/vultr-vpc-details`.

## Overview

Provisions a Vultr VPC with a private IPv4 range that downstream VKE clusters and managed databases attach to for private connectivity.

> **Important:** Vultr Kubernetes Engine (VKE) is only compatible with the **original VPC** (`vultr_vpc`), not VPC 2.0 (`vultr_vpc2`, which is additionally deprecated in the provider). This module therefore uses `vultr_vpc`. An existing VPC can only be attached to a *new* VKE cluster, and both must share the same region.

## Resources Created

- **vultr_vpc**: A private network defined by its network address (`v4_subnet`) and subnet mask (`v4_subnet_mask`)

## Required Configuration

- **Subnet CIDR**: CIDR block for the VPC, e.g. `10.0.0.0/24` (split into network address + mask)
- **Region** (optional): defaults to the cloud account's region when not set

## Inputs

- **Vultr Cloud Account** (`@facets/vultr_cloud_account`): provides the Vultr provider and default region

## Outputs

- `@facets/vultr-vpc-details` (default): `vpc_id`, `vpc_description`, `region`, `ip_block`, `prefix_length`, `subnet_cidr`
