# Onboarding Vultr to Facets

This guide walks you through standing up Vultr as a target cloud in Facets — from credentials to a deployed VKE cluster with networking, storage, and a managed database.

> **Status:** Preview. The Vultr module set is published and importable from this repository. A managed-registry shortcut (`--managed facets/vultr`) will be available once the project type is published to the Facets registry.

---

## 1. Prerequisites

- A **Vultr account** with billing enabled.
- The **Raptor CLI** authenticated to your control plane (`raptor login`).
- A **Vultr API key** — created in the next step.

---

## 2. Create a Vultr API key

1. Go to **https://my.vultr.com/settings/#settingsapi** → enable the API and copy your **Personal Access Token (API Key)**.
2. Under **Access Control**, add the public IP(s) that will run Terraform (your control plane egress) to the allow-list, or temporarily allow all while testing.
3. The same key authorizes all the resources the modules use: Kubernetes (VKE), VPCs, Object Storage, and Managed Databases.
4. Store the key as a secret on the cloud account resource.

---

## 3. Import the Vultr project type

The project type bundles the Vultr cloud modules plus the cloud-agnostic Kubernetes modules (service, KubeBlocks datastores, helm, ingress, cert-manager, monitoring, operators).

```bash
# From a clone of facets-modules-redesign.
# --modules-dir uploads the module code, --outputs-dir registers the output types.
# No --include-base-template, so projects created from this type start empty.
raptor import project-type -f ./project-type/vultr/project-type.yml \
  --modules-dir ./modules --outputs-dir ./outputs

# With a custom display name
raptor import project-type -f ./project-type/vultr/project-type.yml \
  --modules-dir ./modules --outputs-dir ./outputs --name "Vultr Platform"
```

> If the Vultr modules are already published to your control plane, you can omit `--modules-dir`. Omit `--include-base-template` always — this project type intentionally has no base blueprint.

**Prompt for Praxis:**

```
Import the Vultr project type for me from the facets-modules-redesign repo
(project-type/vultr/project-type.yml) along with its output types.
```

---

## 4. Create a project

```bash
raptor create project my-vultr-app --project-type vultr --clouds KUBERNETES
```

---

## 5. Configure the cloud account

Add the `cloud_account/vultr_provider` resource and set the API key (as a secret) and a default region:

```bash
raptor apply resource cloud_account/vultr_provider/1.0 -p my-vultr-app -n cloud \
  --spec '{"api_key":"<YOUR_VULTR_API_KEY>","region":"ewr"}'
```

> Treat the API key as a secret. In the Facets UI it is a secret-reference field; via CLI you can wire it to a project secret/variable instead of inlining it.

**Common regions:** `ewr` (New Jersey), `ord` (Chicago), `lax` (Los Angeles), `atl` (Atlanta), `ams` (Amsterdam), `fra` (Frankfurt), `lhr` (London), `sgp` (Singapore), `nrt` (Tokyo), `syd` (Sydney).

---

## 6. Add the infrastructure

This project type has **no base template** — a new project starts empty and you add resources to the blueprint. Apply in this order (each wires to the resources before it):

```bash
# VPC (legacy VPC — required for VKE; VPC 2.0 is NOT compatible with VKE)
raptor apply resource network/vultr_vpc/1.0 -p my-vultr-app -n network \
  --spec '{"region":"ewr","subnet_cidr":"10.0.0.0/24"}' \
  --input vultr_cloud_account=cloud_account/cloud

# VKE cluster (placed in the VPC; cluster and VPC must share a region)
raptor apply resource kubernetes_cluster/vke/1.0 -p my-vultr-app -n cluster \
  --spec '{"k8s_version":"v1.35.0+1","high_availability":false,"default_pool":{"node_type":"vc2-2c-4gb","node_count":3}}' \
  --input vultr_cloud_account=cloud_account/cloud --input network=network/network

# Extra node pool (optional)
raptor apply resource kubernetes_node_pool/vke/1.0 -p my-vultr-app -n workers \
  --spec '{"node_type":"vc2-2c-4gb","node_count":2}' \
  --input vultr_cloud_account=cloud_account/cloud --input kubernetes_cluster=kubernetes_cluster/cluster

# Object storage
raptor apply resource object_storage/vultr/1.0 -p my-vultr-app -n assets \
  --spec '{"region":"ewr","tier_id":1}' \
  --input vultr_cloud_account=cloud_account/cloud

# Managed PostgreSQL
raptor apply resource postgres/vultr/1.0 -p my-vultr-app -n database \
  --spec '{"version_config":{"version":"16"},"sizing":{"plan":"vultr-dbaas-hobbyist-cc-1-25-1"},"network_access":{"trusted_ips":[]}}' \
  --input vultr_cloud_account=cloud_account/cloud
```

Deploy an app workload with the cloud-agnostic `service/k8s` module, wiring it to the cluster's `attributes` (Kubernetes details) output and a node pool:

```bash
raptor apply resource service/k8s/1.0 -p my-vultr-app -n my-api \
  --input kubernetes_details=kubernetes_cluster/cluster/attributes \
  --input kubernetes_node_pool_details=kubernetes_node_pool/workers
```

---

## 7. Plan and deploy

```bash
raptor plan -p my-vultr-app -e <environment>     # server-side terraform plan
raptor create release -p my-vultr-app -e <environment>
```

---

## Reference

**VKE node plans:** `vc2-1c-2gb`, `vc2-2c-4gb`, `vc2-4c-8gb`, `vc2-6c-16gb`, `vhf-2c-4gb`, `vhf-4c-8gb`
**Managed DB plans:** Vultr DBaaS plan slugs, e.g. `vultr-dbaas-hobbyist-cc-1-25-1` (list via `GET /v2/databases/plans`)
**Kubernetes versions:** full Vultr version strings with build suffix, e.g. `v1.34.1+3`, `v1.35.0+1`, `v1.35.2+1` (list via `GET /v2/kubernetes/versions`)

## Notes & gotchas

- **VKE requires the original VPC, not VPC 2.0:** the `network/vultr_vpc` module uses `vultr_vpc` (legacy). VKE clusters cannot attach to VPC 2.0 networks, and `vultr_vpc2` is deprecated in the provider. An existing VPC can only be attached to a *new* VKE cluster, and both must share a region.
- **VKE provider auth is client-certificate based:** Vultr VKE does not issue a static bearer token. The cluster module derives `client_certificate`/`client_key`/`cluster_ca_certificate` from the kubeconfig and wires them into the Kubernetes and Helm providers.
- **Object storage is a subscription, not a bucket:** `object_storage/vultr` provisions a full S3 endpoint with its own access/secret keys; create buckets against it via the S3 API from your application. There is no module-level ACL/versioning (those are S3-API operations).
- **Managed PostgreSQL access:** the database is reachable only from CIDRs in `network_access.trusted_ips` (empty denies all external access). Add your VKE node egress CIDRs to allow the cluster to connect.
- **Kubernetes & DB versions are volatile full strings/slugs:** unlike a fixed enum, Vultr version strings (`v1.35.0+1`) and DB plan slugs (`vultr-dbaas-*`) change over time. List current values via the Vultr API before deploying.
- **No pod-level cloud IAM:** Vultr has no IRSA/Workload-Identity equivalent. Apps consume object storage via the access key/secret exposed by `object_storage/vultr`, and use Kubernetes-native service accounts (via `service/k8s`).
- **HA control plane** (`high_availability: true`) and larger multi-node DB plans incur additional cost — defaults are single-node/cost-friendly.
