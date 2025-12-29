# **Redis Cluster - KubeBlocks Module**

### Production-grade Redis deployment for Kubernetes using **KubeBlocks v1.0.1**

![Version](https://img.shields.io/badge/version-1.0-blue)
![Cloud](https://img.shields.io/badge/cloud-kubernetes-326CE5)
![Operator](https://img.shields.io/badge/KubeBlocks-v1.0.1-green)

---

## **Overview**

This Terraform module provisions **Redis clusters** on Kubernetes using the **KubeBlocks v1.0.1** operator.
It fully supports:

* **Standalone Redis**
* **Redis Replication (HA via Sentinel)**
* **Redis Cluster (Sharded Redis Cluster)**

The module simplifies complex KubeBlocks CRD definitions into clean Terraform configuration while ensuring:

* High availability
* Automated failover (Sentinel / native cluster)
* Data sharding (redis-cluster mode)
* Backup + restore
* Multi-environment repeatable deployments
* Read service creation for replication mode

---

## **Environment Awareness**

This module automatically adapts to the target environment:

| Feature        | Behavior                                            |
| -------------- | --------------------------------------------------- |
| Namespace      | Uses `environment.namespace` unless overridden      |
| Cloud Tags     | Applied to all managed resources                    |
| Cluster Naming | Consistent naming per environment                   |
| StorageClass   | Configurable per environment (SSD / Standard / CSI) |

This ensures **the same module works in dev, staging, and production** without modification.

---

## **Resources Created**

| Resource               | Description                                             |
| ---------------------- | ------------------------------------------------------- |
| **Cluster (CRD)**      | Main Redis definition using topology **or** shardings   |
| **Namespace**          | Created only when overridden                            |
| **Primary Service**    | Read/write endpoint auto-created by KubeBlocks          |
| **Read Service**       | Terraform-created (replication mode only)               |
| **PVCs**               | One per Redis replica or shard-replica                  |
| **Pods**               | Redis instances managed by KubeBlocks                   |
| **Sentinel Pods**      | Only in replication mode                                |
| **Secrets**            | Auto-generated `conn-credential` with username/password |
| **Backup Config**      | Inline `spec.backup` field when enabled                 |
| **Restore Annotation** | Added when restore is requested                         |

---

## **Deployment Modes**

KubeBlocks v1 uses **two different spec shapes** depending on mode:

---

### 1️⃣ **Standalone Mode**

```
spec:
  clusterDef: redis
  topology: standalone
  componentSpecs: [ redis ]
```

* Single Redis instance
* Lowest complexity
* Best for development or caching workloads

---

### 2️⃣ **Replication Mode (HA via Sentinel)**

```
spec:
  clusterDef: redis
  topology: replication
  componentSpecs:
    - redis (primary + replicas)
    - redis-sentinel (quorum)
```

Includes:

* Redis Sentinel (3 replicas)
* Automatic failover
* Optional read-replica service → **{cluster}-redis-read**

Best for **production HA workloads**.

---

### 3️⃣ **Redis Cluster Mode (Sharded Redis Cluster)**

Uses **shardings** instead of topology:

```
spec:
  shardings:
    - name: shard
      shards: <number_of_shards>
      template:
        componentDef: redis-cluster-7-1.0.1
        replicas: <per_shard_replicas>
```

Characteristics:

* Multi-shard distributed Redis
* Each shard has its own master + replicas
* Client-side routing required (`redis-cli --cluster`, or cluster-aware clients)
* No `clusterDef` or `topology`

Best for **large datasets or horizontal scaling**.

---

## 🔁 **High Availability Features**

| Feature           | Standalone | Replication     | Redis Cluster            |
| ----------------- | ---------- | --------------- | ------------------------ |
| Failover          | ❌ No       | ✅ Sentinel      | ✅ Built-in               |
| Sharding          | ❌ No       | ❌ No            | ✅ Yes                    |
| Read Scaling      | ❌ No       | ✅ Yes           | ⚠️ Client-dependent      |
| Pod Anti-Affinity | Optional   | Enabled         | Enabled                  |
| HA Mode           | None       | Primary/Replica | Multi-shard Multi-master |

Extras in HA modes:

* Automatic failover with Sentinel or Redis Cluster
* Anti-affinity to spread replicas across nodes
* Tolerations for spot / special workloads

---

## **Backup & Restore**

### 🔹 Backup (Snapshot-Based)

This module supports KubeBlocks backup scheduling:

* CSI volume snapshot backups
* Automatic retention cleanup
* CRON-based scheduling
* Configurable retention lifecycle

Example:

```hcl
backup = {
  enabled          = true
  enable_schedule  = true
  schedule_cron    = "0 2 * * *"
  retention_period = "7d"
}
```

---

### 🔹 Restore From Backup

KubeBlocks restore works via an annotation:

```
metadata:
  annotations:
    kubeblocks.io/restore-from-backup: '{ "redis": { "name": "...", "namespace": "..." } }'
```

Module automatically:

* Adds annotation when restore is enabled
* Waits for cluster to reach running state
* Extends timeout for large restores

---

## **Storage Operations**

Supported storage features:

* PVCs created per Redis replica / shard replica
* Automatic PVC expansion when resizing storage
* Storage class override (managed-csi, gp3, etc.)
* Persistence via AOF/RDB hybrid storage

---

## **Version Compatibility**

Validated Redis versions:

* **7.4.x (latest stable)**
* **7.2.x**
* **7.0.x**

Component definitions:

| Mode                   | ComponentDef Format            |
| ---------------------- | ------------------------------ |
| Standalone/Replication | `redis-<major>-1.0.1`          |
| Redis Cluster          | `redis-cluster-<major>-1.0.1`  |
| Sentinel               | `redis-sentinel-<major>-1.0.1` |

---

## **Connection Details**

### **Primary / Writer Connection**

Always exists:

```
<cluster>-redis-redis.<namespace>.svc.cluster.local:6379
```

### **Reader Service (Replication Mode Only)**

```
<cluster>-redis-read.<namespace>.svc.cluster.local:6379
```

---

## **Security Considerations**

* Password included only in Terraform outputs as **sensitive**
* ClusterIP services (no external exposure)
* Namespace isolation
* RBAC-compliant usage (no root privileges)
* Tolerations included for production clusters

---

## **Resource Defaults**

| Setting                | Default     |
| ---------------------- | ----------- |
| CPU Request            | 200m        |
| CPU Limit              | 500m        |
| Memory Request         | 256Mi       |
| Memory Limit           | 512Mi       |
| Storage                | 10Gi        |
| Sentinel Replicas      | 3           |
| Shards                 | 3           |
| Redis Cluster Replicas | 2 per shard |

---

## **Mode Comparison**

| Feature    | Standalone | Replication   | Redis Cluster         |
| ---------- | ---------- | ------------- | --------------------- |
| HA         | ❌          | ✅             | ✅                     |
| Sharding   | ❌          | ❌             | ✅                     |
| Scaling    | Vertical   | Read-only     | Horizontal            |
| Failover   | No         | Sentinel      | Native                |
| Complexity | Low        | Medium        | High                  |
| Best For   | Dev/Test   | HA Production | Large-scale workloads |

---

## **Module Dependencies**

This module requires:

1. **KubeBlocks operator v1.0.1+**
2. **CSI snapshot support** on cluster (for backups)
3. Terraform provider:

   * kubernetes
   * time
   * facets-utility-modules (any-k8s-resource)

---

## **Operational Notes**

### For Redis Cluster Mode:

* Requires at least 3 shards for good distribution
* Needs clients that understand Redis Cluster protocol
* Multi-key ops restricted to keys in same hash slot

### For Replication Mode:

* Sentinel quorum is automatically managed
* Handles failover without downtime
* Reader service becomes active only when replicas exist