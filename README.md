# Facets Modules

Infrastructure as Code modules for the [Facets Control Plane](https://facets.cloud). Provision cloud infrastructure, datastores, Kubernetes resources, and platform tooling across AWS, GCP, and Azure.

```
3 project types  ·  3 clouds
```

---

## Project Types

A project type is a bundle of modules imported to the Control Plane in bulk. Pick your cloud and import everything you need in one command.

---

### AWS

EKS clusters (Standard + Automode), Karpenter autoscaling, managed RDS, Aurora, DocumentDB, ElastiCache, MSK, and full Kubernetes platform tooling.

**Prompt for Praxis:**

```
Import the official Facets AWS project type for me.

raptor import project-type --managed facets/aws
```

**Raptor CLI:**

```bash
raptor import project-type --managed facets/aws
```

With custom name:

```bash
raptor import project-type --managed facets/aws --name "My Platform"
```

<details>
<summary><strong>What's included</strong></summary>

**Infrastructure**
`Cloud Account (aws_provider)` `Network/VPC (aws_network)` `EKS Standard (eks_standard)` `EKS Automode (eks_automode)` `Node Pool/Karpenter (karpenter)` `Node Pool/Automode (eks_automode)` `Karpenter (default)` `AWS ALB Controller (standard)` `EFS CSI Driver (standard)` `AWS EFS (standard)` `StorageClass/EBS (aws_ebs)` `StorageClass/EFS (aws_efs)` `Service (aws)` `AWS IAM Policy (standard)` `AWS IAM Role (standard)`

**Managed Datastores**
`PostgreSQL/RDS (aws-rds)` `PostgreSQL/Aurora (aws-aurora)` `MySQL/RDS (aws-rds)` `MySQL/Aurora (aws-aurora)` `MongoDB/DocumentDB (aws-documentdb)` `Redis/ElastiCache (aws-elasticache)` `Kafka/MSK (aws-msk)`

**Self-hosted via KubeBlocks**
`PostgreSQL` `MySQL` `MongoDB` `Redis`

**K8s Platform**
`Helm` `Ingress/Gateway Fabric` `Ingress/NGINX` `cert-manager` `ConfigMap` `Secrets` `PVC (k8s_standard)` `Access Controls` `Callbacks` `K8s Resources` `Gateway API CRD` `VPA` `Artifactories`

**Operators & Monitoring**
`KubeBlocks` `Strimzi` `ECK` `WireGuard Operator` `WireGuard VPN` `Alert Rules` `Prometheus` `Grafana` `Monitoring`

</details>

---

### GCP

GKE clusters, Cloud SQL, Memorystore, Pub/Sub, Workload Identity, and full Kubernetes platform tooling.

**Prompt for Praxis:**

```
Import the official Facets GCP project type for me.

raptor import project-type --managed facets/gcp
```

**Raptor CLI:**

```bash
raptor import project-type --managed facets/gcp
```

With custom name:

```bash
raptor import project-type --managed facets/gcp --name "My Platform"
```

<details>
<summary><strong>What's included</strong></summary>

**Infrastructure**
`Cloud Account (gcp_provider)` `Network/VPC (gcp_network)` `GKE (gke)` `Node Pool (gcp)` `Node Fleet (gcp_node_fleet)` `Service (gcp)` `Workload Identity (gcp)` `Pub/Sub (gcp)` `GCP Secret Manager (gcp)`

**Managed Datastores**
`PostgreSQL/Cloud SQL (gcp-cloudsql)` `MySQL/Cloud SQL (gcp-cloudsql)` `Redis/Memorystore (gcp-memorystore)`

**Self-hosted via KubeBlocks**
`PostgreSQL` `MySQL` `MongoDB` `Redis`

**K8s Platform**
`Helm` `Ingress/Gateway Fabric` `cert-manager` `ConfigMap` `Secrets` `PVC (k8s_standard)` `Access Controls` `Callbacks` `K8s Resources` `Gateway API CRD` `VPA` `Artifactories`

**Operators & Monitoring**
`KubeBlocks` `Strimzi` `ECK` `WireGuard Operator` `WireGuard VPN` `Alert Rules` `Prometheus` `Grafana` `Monitoring`

</details>

---

### Azure

AKS clusters, Flexible Server (Postgres/MySQL), Cosmos DB, Azure Cache, Workload Identity, and full Kubernetes platform tooling.

**Prompt for Praxis:**

```
Import the official Facets Azure project type for me.

raptor import project-type --managed facets/azure
```

**Raptor CLI:**

```bash
raptor import project-type --managed facets/azure
```

With custom name:

```bash
raptor import project-type --managed facets/azure --name "My Platform"
```

<details>
<summary><strong>What's included</strong></summary>

**Infrastructure**
`Cloud Account (azure_provider)` `Network/VNet (azure_network)` `AKS (aks)` `Node Pool (azure)` `Service (azure)` `Workload Identity (azure)`

**Managed Datastores**
`PostgreSQL/Flexible Server (azure-flexible-server)` `MySQL/Flexible Server (azure-flexible-server)` `MongoDB/Cosmos DB (cosmosdb)` `Redis/Azure Cache (azure_cache_custom)`

**Self-hosted via KubeBlocks**
`PostgreSQL` `MySQL` `MongoDB` `Redis`

**K8s Platform**
`Helm` `Ingress/Gateway Fabric` `cert-manager` `ConfigMap` `Secrets` `PVC (k8s_standard)` `Access Controls` `Callbacks` `K8s Resources` `Gateway API CRD` `VPA` `Artifactories`

**Operators & Monitoring**
`KubeBlocks` `Strimzi` `ECK` `WireGuard Operator` `WireGuard VPN` `Alert Rules` `Prometheus` `Grafana` `Monitoring`

</details>

---

### Vultr — Preview

VKE (Vultr Kubernetes Engine) clusters with node pools, Vultr VPC networking, S3-compatible object storage, managed PostgreSQL, and a cloud-agnostic Kubernetes service — plus the shared K8s platform and KubeBlocks datastores.

**First, create a Vultr API key** at https://my.vultr.com/settings/#settingsapi and add your control plane egress IP to the API access-control allow-list. Full walkthrough: [`project-type/vultr/ONBOARDING.md`](project-type/vultr/ONBOARDING.md).

**Prompt for Praxis:**

```
Import the Vultr project type for me from the facets-modules-redesign repo
(project-type/vultr/project-type.yml) along with its output types.
```

**Raptor CLI:** (imports the project type + modules + outputs; no base template — projects start empty)

```bash
raptor import project-type -f ./project-type/vultr/project-type.yml \
  --modules-dir ./modules --outputs-dir ./outputs
```

With custom name:

```bash
raptor import project-type -f ./project-type/vultr/project-type.yml \
  --modules-dir ./modules --outputs-dir ./outputs --name "Vultr Platform"
```

<details>
<summary><strong>What's included</strong></summary>

**Infrastructure**
`Cloud Account (vultr_provider)` `Network/VPC (vultr_vpc)` `VKE Cluster (vke)` `Node Pool (vke)` `Object Storage (vultr)` `Service (k8s)`

**Managed Datastores**
`PostgreSQL (vultr)`

**Self-hosted via KubeBlocks**
`PostgreSQL` `MySQL` `MongoDB` `Redis`

**K8s Platform**
`Helm` `Ingress/NGINX` `cert-manager` `ConfigMap` `Secrets` `PVC` `Access Controls` `Callbacks` `K8s Resources` `Gateway API CRD` `Artifactories`

**Operators & Monitoring**
`KubeBlocks` `ECK` `Prometheus` `Grafana` `Alert Rules` `Monitoring`

</details>

---

## Links

- [Facets Control Plane](https://facets.cloud)
- [Praxis AI](https://askpraxis.ai)
