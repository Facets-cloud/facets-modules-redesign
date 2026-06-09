# Linode Kubernetes Engine (LKE) Cluster

Creates an LKE cluster with a default node pool and exposes the Kubernetes and Helm providers for downstream modules. Produces `@facets/lke` (cluster attributes) and `@facets/kubernetes-details` (generic attributes + provider configuration).

## Overview

LKE requires at least one node pool at creation, so this module provisions a configurable default pool alongside the control plane. Additional pools can be added with the `kubernetes_node_pool/lke` module. The Kubernetes and Helm providers are configured from the cluster kubeconfig (token-based authentication).

## Resources Created

- **linode_lke_cluster**: The managed Kubernetes control plane plus a default node pool

## Required Configuration

- **Kubernetes Version**: One of `1.31`, `1.32`, `1.33`
- **Default Node Pool**: `node_type` (e.g. `g6-standard-2`) and `node_count`
- **High Availability** (optional): HA control plane (additional cost), default off
- **Autoscaler** (optional): enable per-pool autoscaling with min/max

## Inputs

- **Linode Cloud Account** (`@facets/linode_cloud_account`): provides the Linode provider and region
- **Linode VPC** (`@facets/linode-vpc-details`, optional): when wired, the cluster nodes are placed in the VPC's subnet (`vpc_id` + `subnet_id`) and the cluster region is taken from the VPC

## Outputs

- `@facets/lke` (default): `cluster_id`, `cluster_name`, `cluster_endpoint`, `region`, `k8s_version`, `status`, `dashboard_url`, `kubeconfig`
- `@facets/kubernetes-details` (attributes): generic cluster details plus configured `kubernetes` and `helm` providers
