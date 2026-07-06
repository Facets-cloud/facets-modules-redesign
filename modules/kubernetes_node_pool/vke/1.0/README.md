# Vultr Kubernetes Engine (VKE) Node Pool

Adds and manages an additional node pool on an existing VKE cluster. Produces `@facets/kubernetes_nodepool`.

## Overview

Provisions a standalone VKE node pool with optional autoscaling, labels, and taints, attached to a cluster created by `kubernetes_cluster/vke`.

## Resources Created

- **vultr_kubernetes_node_pools**: An additional node pool on the target cluster

## Required Configuration

- **Node Plan** (`node_type`): Vultr compute plan, e.g. `vc2-2c-4gb`
- **Node Count**: number of nodes (initial count when autoscaling)
- **Autoscaler** (optional): enable autoscaling with min/max
- **Labels / Taints** (optional): Kubernetes node labels and taints applied to the pool

## Inputs

- **Vultr Cloud Account** (`@facets/vultr_cloud_account`): provides the Vultr provider
- **VKE Cluster** (`@facets/vke`): the cluster to add the node pool to (defaults to the `default` kubernetes_cluster resource)

## Outputs

- `@facets/kubernetes_nodepool` (default): `node_pool_name`, `node_class_name`, `taints`, `node_selector`
