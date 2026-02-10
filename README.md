# Facets Modules

Infrastructure as Code modules for the [Facets Control Plane](https://facets.cloud). Provision cloud infrastructure, datastores, Kubernetes resources, and platform tooling across AWS, GCP, and Azure.

**[Browse the Module Catalog](https://facets-cloud.github.io/facets-modules-redesign/)**

```
63 modules  ·  3 project types  ·  45 output types  ·  3 clouds
```

---

## Project Types

A project type is a bundle of modules imported to the Control Plane in bulk. Pick your cloud and import everything you need in one command.

---

### AWS — 40 modules

EKS clusters (Standard + Automode), Karpenter autoscaling, managed RDS, Aurora, DocumentDB, ElastiCache, MSK, and full Kubernetes platform tooling.

**Ask Praxis AI:**

> Import the official Facets AWS project type for me.
>
> `raptor import project-type --managed facets/aws`

**Raptor CLI:**

```bash
raptor import project-type --managed facets/aws

# With custom name
raptor import project-type --managed facets/aws --name "My Platform"
```

<details>
<summary><strong>What's included (40 modules)</strong></summary>

**Infrastructure** (8)
`Cloud Account (aws_provider)` `Network/VPC (aws_network)` `EKS Standard (eks_standard)` `EKS Automode (eks_automode)` `Node Pool/Karpenter (karpenter)` `Node Pool/Automode (eks_automode)` `Karpenter (default)` `Service (aws)`

**Managed Datastores** (7)
`PostgreSQL/RDS (aws-rds)` `PostgreSQL/Aurora (aws-aurora)` `MySQL/RDS (aws-rds)` `MySQL/Aurora (aws-aurora)` `MongoDB/DocumentDB (aws-documentdb)` `Redis/ElastiCache (aws-elasticache)` `Kafka/MSK (aws-msk)`

**Self-hosted via KubeBlocks** (4)
`PostgreSQL` `MySQL` `MongoDB` `Redis`

**K8s Platform** (12)
`Helm` `Ingress/Gateway Fabric` `Ingress/NGINX` `cert-manager` `ConfigMap` `Secrets` `Access Controls` `Callbacks` `K8s Resources` `Gateway API CRD` `VPA` `Artifactories`

**Operators & Monitoring** (9)
`KubeBlocks` `Strimzi` `ECK` `WireGuard Operator` `WireGuard VPN` `Alert Rules` `Prometheus` `Grafana` `Monitoring`

</details>

---

### GCP — 35 modules

GKE clusters, Cloud SQL, Memorystore, Pub/Sub, Workload Identity, and full Kubernetes platform tooling.

**Ask Praxis AI:**

> Import the official Facets GCP project type for me.
>
> `raptor import project-type --managed facets/gcp`

**Raptor CLI:**

```bash
raptor import project-type --managed facets/gcp

# With custom name
raptor import project-type --managed facets/gcp --name "My Platform"
```

<details>
<summary><strong>What's included (35 modules)</strong></summary>

**Infrastructure** (8)
`Cloud Account (gcp_provider)` `Network/VPC (gcp_network)` `GKE (gke)` `Node Pool (gcp)` `Node Fleet (gcp_node_fleet)` `Service (gcp)` `Workload Identity (gcp)` `Pub/Sub (gcp)`

**Managed Datastores** (3)
`PostgreSQL/Cloud SQL (gcp-cloudsql)` `MySQL/Cloud SQL (gcp-cloudsql)` `Redis/Memorystore (gcp-memorystore)`

**Self-hosted via KubeBlocks** (4)
`PostgreSQL` `MySQL` `MongoDB` `Redis`

**K8s Platform** (11)
`Helm` `Ingress/Gateway Fabric` `cert-manager` `ConfigMap` `Secrets` `Access Controls` `Callbacks` `K8s Resources` `Gateway API CRD` `VPA` `Artifactories`

**Operators & Monitoring** (9)
`KubeBlocks` `Strimzi` `ECK` `WireGuard Operator` `WireGuard VPN` `Alert Rules` `Prometheus` `Grafana` `Monitoring`

</details>

---

### Azure — 34 modules

AKS clusters, Flexible Server (Postgres/MySQL), Cosmos DB, Azure Cache, Workload Identity, and full Kubernetes platform tooling.

**Ask Praxis AI:**

> Import the official Facets Azure project type for me.
>
> `raptor import project-type --managed facets/azure`

**Raptor CLI:**

```bash
raptor import project-type --managed facets/azure

# With custom name
raptor import project-type --managed facets/azure --name "My Platform"
```

<details>
<summary><strong>What's included (34 modules)</strong></summary>

**Infrastructure** (6)
`Cloud Account (azure_provider)` `Network/VNet (azure_network)` `AKS (aks)` `Node Pool (azure)` `Service (azure)` `Workload Identity (azure)`

**Managed Datastores** (4)
`PostgreSQL/Flexible Server (azure-flexible-server)` `MySQL/Flexible Server (azure-flexible-server)` `MongoDB/Cosmos DB (cosmosdb)` `Redis/Azure Cache (azure_cache_custom)`

**Self-hosted via KubeBlocks** (4)
`PostgreSQL` `MySQL` `MongoDB` `Redis`

**K8s Platform** (11)
`Helm` `Ingress/Gateway Fabric` `cert-manager` `ConfigMap` `Secrets` `Access Controls` `Callbacks` `K8s Resources` `Gateway API CRD` `VPA` `Artifactories`

**Operators & Monitoring** (9)
`KubeBlocks` `Strimzi` `ECK` `WireGuard Operator` `WireGuard VPN` `Alert Rules` `Prometheus` `Grafana` `Monitoring`

</details>

---

## Repository Structure

```
.
├── index.html                            # Module catalog (GitHub Pages)
├── project-type/
│   ├── aws/project-type.yml              # AWS project type definition
│   ├── gcp/project-type.yml              # GCP project type definition
│   └── azure/project-type.yml            # Azure project type definition
├── modules/
│   ├── cloud_account/{flavor}/1.0/       # Cloud provider accounts
│   ├── network/{flavor}/1.0/             # VPC / VNet networking
│   ├── kubernetes_cluster/{flavor}/1.0/  # EKS / GKE / AKS clusters
│   ├── kubernetes_node_pool/{flavor}/1.0/
│   ├── karpenter/default/1.0/            # Karpenter autoscaler
│   ├── service/{flavor}/1.0/             # Container services
│   ├── pubsub/gcp/1.0/                  # GCP Pub/Sub
│   ├── workload_identity/{flavor}/1.0/   # Cloud IAM identity
│   ├── datastore/
│   │   ├── postgres/{flavor}/1.0/        # RDS, Aurora, CloudSQL, Flexible Server, KubeBlocks
│   │   ├── mysql/{flavor}/1.0/           # RDS, Aurora, CloudSQL, Flexible Server, KubeBlocks
│   │   ├── mongo/{flavor}/1.0/           # DocumentDB, CosmosDB, KubeBlocks
│   │   ├── redis/{flavor}/1.0/           # ElastiCache, Memorystore, Azure Cache, KubeBlocks
│   │   ├── kafka/{flavor}/1.0/           # MSK
│   │   └── kafka_topic/{flavor}/1.0/
│   └── common/                           # Shared K8s modules (Helm, Ingress, cert-manager, etc.)
├── outputs/                              # Output type schemas (@facets/*)
├── icons/                                # Module SVG icons
└── app/internal/                         # Internal dev tools (graph, wiring explorer)
```

### Module Files

Each module at `{intent}/{flavor}/{version}/` contains:

| File | Purpose |
|------|---------|
| `facets.yaml` | Module definition — spec schema, inputs, outputs, sample config |
| `variables.tf` | Input variables (`var.instance` for spec, `var.inputs` for dependencies) |
| `main.tf` | Terraform resources |
| `locals.tf` | Output attributes and interfaces |
| `outputs.tf` | Terraform outputs |

## Working with Modules

### Validate a module

```bash
raptor create iac-module -f modules/service/aws/1.0 --dry-run
```

### Upload a module

```bash
raptor create iac-module -f modules/service/aws/1.0
```

### Add a single module to an existing project type

```bash
raptor create resource-type-mapping my-project-type \
  --resource-type service/aws
```

### List available resource types

```bash
raptor get resource-types
```

## Key Concepts

```
PROJECT TYPE ─── a bundle of modules imported to Control Plane in bulk
  └── MODULE ─── Terraform code for one resource type (intent/flavor/version)
       ├── INPUTS ── dependencies on other modules' outputs
       └── OUTPUTS ── values exposed via @facets/* output types

RESOURCE ─── an instance of a module in your project blueprint
  └── wired to other resources via input/output references
```

## Module Standards

Each module category has a standards document:

- `modules/service/service_module_standard.md`
- `modules/network/network_module_standard.md`
- `modules/cloud_account/cloud_account_module_standard.md`
- `modules/kubernetes_node_pool/kubernetes_node_pool_module_standard.md`
- `modules/workload_identity/workload_identity_module_standard.md`
- `modules/datastore/datastore_module_standards.md`

See `rules.md` for the complete validation ruleset.

## Internal Dev Tools

```bash
cd app/internal && python3 -m http.server 8765
```

| Page | URL | Purpose |
|------|-----|---------|
| Icon Catalog | `localhost:8765/icons.html` | All module icons with flavor/cloud matrix |
| Dependency Graph | `localhost:8765/graph.html` | Interactive module dependency visualization |
| Wiring Explorer | `localhost:8765/wiring.html` | Attribute-level input/output wiring details |

## Links

- [Facets Control Plane](https://facets.cloud)
- [Praxis AI](https://askpraxis.ai)
- [Module Catalog](https://facets-cloud.github.io/facets-modules-redesign/)
