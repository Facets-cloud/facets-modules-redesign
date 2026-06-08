# Onboarding Linode (Akamai) to Facets

This guide walks you through standing up Linode (Akamai Cloud) as a target cloud in Facets — from credentials to a deployed LKE cluster with networking, storage, and a managed database.

> **Status:** Preview. The Linode module set is published and importable from this repository. A managed-registry shortcut (`--managed facets/linode`) will be available once the project type is published to the Facets registry.

---

## 1. Prerequisites

- A **Linode (Akamai Cloud) account** with billing enabled.
- The **Raptor CLI** authenticated to your control plane (`raptor login`).
- A **Linode Personal Access Token (PAT)** — created in the next step.

---

## 2. Create a Linode API token

1. Go to **https://cloud.linode.com/profile/tokens** → **Create a Personal Access Token**.
2. Give it a label (e.g. `facets-control-plane`) and an expiry that suits your policy.
3. Grant **Read/Write** on the scopes the modules use:

   | Scope | Used by |
   |---|---|
   | Linodes | LKE nodes |
   | Kubernetes | LKE cluster + node pools |
   | VPCs | network/linode_vpc |
   | IPs | LKE / VPC networking |
   | Object Storage | object_storage/linode |
   | Databases | postgres/linode |

4. **Copy the token now** — Linode shows it only once. You'll store it as a secret on the cloud account resource.

---

## 3. Import the Linode project type

The project type bundles the Linode cloud modules plus the cloud-agnostic Kubernetes modules (service, KubeBlocks datastores, helm, ingress, cert-manager, monitoring, operators).

```bash
# From a clone of facets-modules-redesign
raptor import project-type -f ./project-type/linode/project-type.yml --outputs-dir ./outputs

# With a custom display name
raptor import project-type -f ./project-type/linode/project-type.yml --outputs-dir ./outputs --name "Linode Platform"
```

**Prompt for Praxis:**

```
Import the Linode project type for me from the facets-modules-redesign repo
(project-type/linode/project-type.yml) along with its output types.
```

---

## 4. Create a project

```bash
raptor create project my-linode-app --project-type linode --clouds KUBERNETES
```

---

## 5. Configure the cloud account

Add the `cloud_account/linode_provider` resource and set the API token (as a secret) and a default region:

```bash
raptor apply resource cloud_account/linode_provider/1.0 -p my-linode-app -n cloud \
  --spec '{"token":"<YOUR_LINODE_TOKEN>","region":"us-east"}'
```

> Treat the token as a secret. In the Facets UI it is a secret-reference field; via CLI you can wire it to a project secret/variable instead of inlining it.

**Common regions:** `us-east` (Newark), `us-ord` (Chicago), `us-central` (Dallas), `eu-west` (London), `eu-central` (Frankfurt), `ap-south` (Singapore).

---

## 6. Add the infrastructure (or use the base blueprint)

The project type ships a base blueprint wiring all resources. To build it by hand, apply in this order (each wires to the resources before it):

```bash
# VPC
raptor apply resource network/linode_vpc/1.0 -p my-linode-app -n network \
  --spec '{"region":"us-east","subnet_cidr":"10.0.0.0/24"}' \
  --input linode_cloud_account=cloud_account/cloud

# LKE cluster (placed in the VPC subnet)
raptor apply resource kubernetes_cluster/lke/1.0 -p my-linode-app -n cluster \
  --spec '{"k8s_version":"1.32","high_availability":false,"default_pool":{"node_type":"g6-standard-2","node_count":3}}' \
  --input linode_cloud_account=cloud_account/cloud --input network=network/network

# Extra node pool (optional)
raptor apply resource kubernetes_node_pool/lke/1.0 -p my-linode-app -n workers \
  --spec '{"node_type":"g6-standard-2","node_count":2}' \
  --input linode_cloud_account=cloud_account/cloud --input kubernetes_cluster=kubernetes_cluster/cluster

# Object storage
raptor apply resource object_storage/linode/1.0 -p my-linode-app -n assets \
  --spec '{"region":"us-east","acl":"private"}' \
  --input linode_cloud_account=cloud_account/cloud

# Managed PostgreSQL
raptor apply resource postgres/linode/1.0 -p my-linode-app -n database \
  --spec '{"version_config":{"version":"16"},"sizing":{"type":"g6-nanode-1","cluster_size":1},"network_access":{"allow_list":[]}}' \
  --input linode_cloud_account=cloud_account/cloud
```

Deploy an app workload with the cloud-agnostic `service/k8s` module, wiring it to the cluster's `attributes` (Kubernetes details) output and a node pool:

```bash
raptor apply resource service/k8s/1.0 -p my-linode-app -n my-api \
  --input kubernetes_details=kubernetes_cluster/cluster/attributes \
  --input kubernetes_node_pool_details=kubernetes_node_pool/workers
```

---

## 7. Plan and deploy

```bash
raptor plan -p my-linode-app -e <environment>     # server-side terraform plan
raptor create release -p my-linode-app -e <environment>
```

---

## Reference

**LKE node types:** `g6-standard-1/2/4/6`, `g6-dedicated-2/4/8`
**Managed DB types:** `g6-nanode-1`, `g6-standard-1/2`, `g6-dedicated-2/4`
**Kubernetes versions:** `1.31`, `1.32`, `1.33`

## Notes & gotchas

- **Managed PostgreSQL access:** the database is reachable only from CIDRs in `network_access.allow_list` (empty denies all external access). Add your LKE node egress CIDRs to allow the cluster to connect.
- **Object storage is region-scoped:** the bucket region is independent of the cluster region; set it explicitly.
- **No pod-level cloud IAM:** Linode has no IRSA/Workload-Identity equivalent. Apps consume object storage via the access key/secret exposed by `object_storage/linode`, and use Kubernetes-native service accounts (via `service/k8s`).
- **HA control plane** (`high_availability: true`) and multi-node DB clusters (`cluster_size: 3`) incur additional cost — defaults are single-node/cost-friendly.
