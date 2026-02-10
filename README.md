# Facets Modules

Infrastructure as Code modules for the [Facets Control Plane](https://facets.cloud). Provision cloud infrastructure, datastores, Kubernetes resources, and platform tooling across AWS, GCP, and Azure.

**[Browse the Module Catalog](https://facets-cloud.github.io/facets-modules-redesign/)**

## Quick Start

Import a complete project type with one command using [Raptor CLI](https://facets.cloud):

```bash
# AWS — EKS, RDS, ElastiCache, MSK, and 40 modules
raptor import project-type --managed facets/aws

# GCP — GKE, Cloud SQL, Memorystore, and 35 modules
raptor import project-type --managed facets/gcp

# Azure — AKS, Flexible Server, Cosmos DB, and 34 modules
raptor import project-type --managed facets/azure
```

Or ask [Praxis AI](https://askpraxis.ai):

> Import the official Facets AWS project type for me.
> `raptor import project-type --managed facets/aws`

## What's Inside

```
63 modules  ·  3 project types  ·  45 output types  ·  3 clouds
```

### Project Types

| Type | Cloud | Modules | Highlights |
|------|-------|---------|------------|
| `facets/aws` | AWS | 40 | EKS (Standard + Automode), Karpenter, RDS, Aurora, DocumentDB, ElastiCache, MSK |
| `facets/gcp` | GCP | 35 | GKE, Cloud SQL, Memorystore, Pub/Sub, Workload Identity |
| `facets/azure` | Azure | 34 | AKS, Flexible Server, Cosmos DB, Azure Cache, Workload Identity |

All project types include shared Kubernetes platform tooling (Helm, Ingress, cert-manager, Prometheus, etc.) and self-hosted datastores via KubeBlocks.

### Module Categories

| Category | Examples |
|----------|----------|
| **Infrastructure** | Cloud Account, Network, K8s Cluster, Node Pools, Service |
| **Managed Datastores** | PostgreSQL, MySQL, MongoDB, Redis, Kafka |
| **Self-hosted Datastores** | PostgreSQL, MySQL, MongoDB, Redis (via KubeBlocks) |
| **Kubernetes Platform** | Helm, Ingress, cert-manager, ConfigMap, Secrets, VPA, Gateway API |
| **Operators** | KubeBlocks, Strimzi, ECK, WireGuard |
| **Monitoring** | Prometheus, Grafana, Alert Rules, Monitoring |

## Repository Structure

```
.
├── index.html                          # Module catalog (GitHub Pages)
├── project-type/
│   ├── aws/project-type.yml            # AWS project type definition
│   ├── gcp/project-type.yml            # GCP project type definition
│   └── azure/project-type.yml          # Azure project type definition
├── modules/
│   ├── cloud_account/{flavor}/1.0/     # Cloud provider accounts
│   ├── network/{flavor}/1.0/           # VPC / VNet networking
│   ├── kubernetes_cluster/{flavor}/1.0/ # EKS / GKE / AKS clusters
│   ├── kubernetes_node_pool/{flavor}/1.0/
│   ├── karpenter/default/1.0/          # Karpenter autoscaler
│   ├── service/{flavor}/1.0/           # Container services
│   ├── pubsub/gcp/1.0/                # GCP Pub/Sub
│   ├── workload_identity/{flavor}/1.0/ # Cloud IAM identity
│   ├── datastore/
│   │   ├── postgres/{flavor}/1.0/      # PostgreSQL (RDS, Aurora, CloudSQL, Flex, KubeBlocks)
│   │   ├── mysql/{flavor}/1.0/         # MySQL (RDS, Aurora, CloudSQL, Flex, KubeBlocks)
│   │   ├── mongo/{flavor}/1.0/         # MongoDB (DocumentDB, CosmosDB, KubeBlocks)
│   │   ├── redis/{flavor}/1.0/         # Redis (ElastiCache, Memorystore, Azure Cache, KubeBlocks)
│   │   ├── kafka/{flavor}/1.0/         # Kafka (MSK)
│   │   └── kafka_topic/{flavor}/1.0/
│   └── common/                         # Shared K8s modules (Helm, Ingress, cert-manager, etc.)
├── outputs/                            # Output type schemas (@facets/*)
├── icons/                              # Module SVG icons
└── app/internal/                       # Internal dev tools (graph, wiring explorer)
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

### Import with a custom name

```bash
raptor import project-type --managed facets/aws --name "Production AWS"
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

Start a local server to access internal review pages:

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
