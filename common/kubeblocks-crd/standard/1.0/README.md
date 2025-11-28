# KubeBlocks CRDs Module

## Overview

This module installs KubeBlocks Custom Resource Definitions (CRDs) on a Kubernetes cluster. The CRDs define the resource types required by the KubeBlocks operator to manage database clusters. This module handles large CRDs (>5MB) that cannot be managed through Helm due to storage limitations.

## Environment as Dimension

This module is environment-agnostic. The same CRD version is deployed across all environments. CRDs are cluster-scoped resources that do not vary per environment.

## Resources Created

- **KubeBlocks Custom Resource Definitions** - Cluster-scoped CRD resources fetched from the KubeBlocks GitHub releases
- **Release ID tracking resources** - UUID generators for dependency tracking with dependent modules

## Module Dependencies

This module must be deployed **before** the `kubeblocks-operator` module. The operator requires these CRDs to be present before it can start managing database resources.

## Dependency Tracking

This module exposes `release_id` and `dependency_id` outputs that are used by consuming modules (like `kubeblocks-operator`) to ensure proper deployment sequencing. The IDs are embedded as annotations in dependent resources to create explicit ordering.

## CRD Management

CRDs are installed using `kubernetes_manifest` resources rather than Helm because:
- KubeBlocks CRDs exceed 5MB in size
- Helm has a 1MB limit for release metadata storage
- Direct Kubernetes API calls via `kubernetes_manifest` have no size restrictions

## Version Management

The CRD version is controlled by the `version` parameter in the module spec. When updating to a new KubeBlocks version, update this parameter to fetch and apply the corresponding CRDs.

## Security Considerations

CRDs are cluster-scoped resources that define new API types. Ensure proper RBAC policies are in place to control who can create instances of these custom resources.
