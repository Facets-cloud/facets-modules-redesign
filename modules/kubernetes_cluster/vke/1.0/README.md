# Vultr Kubernetes Engine (VKE) Cluster

Creates a VKE cluster with a default node pool and exposes the Kubernetes and Helm providers for downstream modules. Produces `@facets/vke` (cluster attributes) and `@facets/kubernetes-details` (generic attributes + provider configuration).

## Overview

VKE requires at least one node pool at creation, so this module provisions a configurable default pool alongside the control plane. Additional pools can be added with the `kubernetes_node_pool/vke` module. The Kubernetes and Helm providers are configured from the cluster kubeconfig using **client-certificate/key authentication** (Vultr VKE does not issue a static bearer token).

## Resources Created

- **vultr_kubernetes**: The managed Kubernetes control plane plus an inline default node pool

## Required Configuration

- **Kubernetes Version**: A Vultr VKE version string including the build suffix, e.g. `v1.35.0+1` (list current values via `GET /v2/kubernetes/versions`)
- **Default Node Pool**: `node_type` (Vultr plan, e.g. `vc2-2c-4gb`) and `node_count`
- **High Availability** (optional): HA control plane (additional cost), default off
- **Enable Managed Firewall** (optional): provision a Vultr-managed firewall group for the nodes, default off
- **Autoscaler** (optional): enable per-pool autoscaling with min/max

## Inputs

- **Vultr Cloud Account** (`@facets/vultr_cloud_account`): provides the Vultr provider and region
- **Vultr VPC** (`@facets/vultr-vpc-details`, optional): when wired, the cluster nodes are placed in the VPC (`vpc_id`) and the cluster region is taken from the VPC. VKE supports the original VPC only.

## Outputs

- `@facets/vke` (default): `cluster_id`, `cluster_name`, `cluster_endpoint`, `region`, `k8s_version`, `status`, `cluster_subnet`, `kubeconfig`, plus `cluster_ca_certificate`/`client_certificate`/`client_key`
- `@facets/kubernetes-details` (attributes): generic cluster details plus configured `kubernetes` and `helm` providers
