# KubeBlocks CRDs Module

## Overview

This module installs the **KubeBlocks Custom Resource Definitions (CRDs)** on a Kubernetes cluster.
KubeBlocks CRDs define all API types required by the KubeBlocks operator to manage stateful data services such as PostgreSQL, MySQL, Redis, MongoDB, Kafka, and more.

This module is designed specifically to handle **large CRD files (>5MB)** that cannot be installed through Helm due to release metadata storage limitations.

> **Default Version: `v1.0.1`**
> This module is tested, validated, and fully compatible with KubeBlocks **v1.0.1**, and this version should be used by default across all Facets modules.
>
> It forms the base of the dependency chain:
> **kubeblocks-crd → kubeblocks-operator → addons (Redis, PostgreSQL, MySQL, etc.)**

---

## Environment as Dimension

This module is **environment-agnostic**:

* CRDs are **cluster-scoped**, not namespaced.
* The same CRD version (`v1.0.1`) is applied consistently across all environments: dev, stage, prod.
* No environment-specific configuration is needed.

Because CRDs define API types, not workloads, they must be identical in all environments to ensure operator/API compatibility.

---

## Resources Created

This module creates the following resources:

### **1. KubeBlocks Custom Resource Definitions**

All CRDs included in the official KubeBlocks release bundle:

* `Cluster`
* `ComponentDefinition`
* `ClusterDefinition`
* `OpsRequest`
* `ClusterBackup`
* `ClusterRestore`
* `Addon`
* `VarRef` types
  and many more (full list depends on v1.0.1 release).

CRDs are pulled directly from the **KubeBlocks GitHub Release: `v1.0.1`**.

### **2. Release Tracking Resources**

The module also creates **UUID-based tracking IDs**:

* `release_id`
* `dependency_id`

These identifiers are used by other modules to enforce **strict sequencing** and avoid race conditions.

---

## Module Dependencies

This module must be applied **first** in the KubeBlocks dependency chain.

### Dependency Chain

```text
1. kubeblocks-crd        (installs CRDs)
2. kubeblocks-operator   (installs operator that consumes CRDs)
3. kubeblocks-addons     (Redis, PostgreSQL, MySQL, MongoDB, Kafka, etc.)
```

The KubeBlocks operator **will not start** unless these CRDs are already installed.

The addon modules (Redis/Postgres/MySQL) depend on the operator and indirectly on these CRDs.

---

## Dependency Tracking

This module exposes:

* **release_id** – unique identifier for each deployment of CRDs
* **dependency_id** – unique ID passed to dependent modules to enforce ordering

These IDs are embedded into dependent resources as annotations such as:

```yaml
kubeblocks.io/operator-dependency-id: <dependency_id>
kubeblocks.io/operator-release-id: <release_id>
```

This guarantees that:

* CRDs are installed **before** the operator
* Operator is installed **before** any addon module
* Upgrades follow a consistent and predictable sequence

---

## CRD Management Strategy

CRDs are installed using **`kubernetes_manifest`** instead of Helm because:

* Many KubeBlocks CRDs exceed **5 MB**
* Helm has a **1MB limit** on release metadata storage in Secrets/ConfigMaps
* Applying CRDs via direct Kubernetes API calls avoids this limitation entirely
* CRDs can be replaced or updated without Helm lifecycle conflicts

This ensures the module is **robust**, **future-proof**, and capable of handling large CRD bundles.

---

## Version Management

The module is currently pinned to:

### **KubeBlocks CRD Version: `v1.0.1` (Default & Recommended)**

This version is:

* Thoroughly tested across all Facets modules
* Compatible with:

  * `kubeblocks-operator v1.0.1`
  * All official addons released for v1.0.1
  * Our Terraform modules (`redis`, `postgres`, `mysql`, etc.)

If a future upgrade is needed:

* Update the `version` field in `facets.yaml`
* The module will fetch CRDs for the new target version from GitHub
* Dependent modules will automatically re-trigger due to updated IDs

---

## Security Considerations

* CRDs are **cluster-scoped**, so they require elevated permissions to install.
* Ensure only cluster administrators can apply or modify CRDs.
* CRDs define API surfaces for databases—incorrect or incompatible CRD versions can break operator functionality.
* RBAC policies should restrict who can create or modify the new resources defined by these CRDs.
