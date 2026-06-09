# Linode Kubernetes Engine (LKE) Node Pool

Adds an additional node pool to an existing LKE cluster. Produces the `@facets/kubernetes_nodepool` output type.

## Overview

The LKE cluster module always creates a default pool; use this module to attach extra pools with different instance types, autoscaling settings, labels, or taints.

## Resources Created

- **linode_lke_node_pool**: An additional node pool attached to the target LKE cluster

## Required Configuration

- **Node Type**: Linode instance type (e.g. `g6-standard-2`)
- **Node Count**: Number of nodes (initial count when autoscaling)
- **Autoscaler** (optional): enable with min/max
- **Labels / Taints** (optional): node labels and taints

## Inputs

- **Linode Cloud Account** (`@facets/linode_cloud_account`): provides the Linode provider
- **LKE Cluster** (`@facets/lke`): the cluster to attach the pool to

## Outputs

- `@facets/kubernetes_nodepool`: `node_pool_name`, `taints`, `node_selector`
