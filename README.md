# Facets Modules Inventory

This document provides a comprehensive list of all Terraform modules in the facets-modules-redesign repository, organized by intent and flavor.

**Total Modules:** 54

---

## Table of Contents
- [Datastore Modules](#datastore-modules)
  - [Kafka](#kafka)
  - [Kafka Topic](#kafka-topic)
  - [MongoDB](#mongodb)
  - [MySQL](#mysql)
  - [PostgreSQL](#postgresql)
  - [Redis](#redis)
- [Core Modules](#core-modules)
  - [Cloud Account](#cloud-account)
  - [Kubernetes Cluster](#kubernetes-cluster)
  - [Kubernetes Node Pool](#kubernetes-node-pool)
  - [Network](#network)
  - [Service](#service)
  - [PubSub](#pubsub)
  - [Workload Identity](#workload-identity)
- [Common Modules](#common-modules)
  - [Artifactories](#artifactories)
  - [Cert Manager](#cert-manager)
  - [Config Map](#config-map)
  - [ECK Operator](#eck-operator)
  - [Grafana Dashboards](#grafana-dashboards)
  - [Helm](#helm)
  - [Ingress](#ingress)
  - [K8s Callback](#k8s-callback)
  - [K8s Resource](#k8s-resource)
  - [KubeBlocks CRD](#kubeblocks-crd)
  - [KubeBlocks Operator](#kubeblocks-operator)
  - [Kubernetes Secret](#kubernetes-secret)
  - [Prometheus](#prometheus)
  - [Strimzi Operator](#strimzi-operator)
  - [VPA](#vpa)

---

## Datastore Modules

### Kafka
Manages Kafka clusters across different cloud providers.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `datastore/kafka/aws-msk/1.0` | kafka | aws-msk | 1.0 |
| `datastore/kafka/gcp-msk/1.0` | kafka | gcp-msk | 1.0 |

### Kafka Topic
Manages Kafka topics.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `datastore/kafka_topic/gcp-msk/1.0` | kafka_topic | gcp-msk | 1.0 |

### MongoDB
Manages MongoDB/DocumentDB databases across platforms.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `datastore/mongo/aws-documentdb/1.0` | mongo | aws-documentdb | 1.0 |
| `datastore/mongo/cosmosdb/1.0` | mongo | cosmosdb | 1.0 |
| `datastore/mongo/k8s_standard/1.0` | mongo | k8s_standard | 1.0 |

### MySQL
Manages MySQL databases across cloud providers and Kubernetes.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `datastore/mysql/aws-aurora/1.0` | mysql | aws-aurora | 1.0 |
| `datastore/mysql/aws-rds/1.0` | mysql | aws-rds | 1.0 |
| `datastore/mysql/flexible_server/1.0` | mysql | azure-flexible-server | 1.0 |
| `datastore/mysql/gcp-cloudsql/1.0` | mysql | gcp-cloudsql | 1.0 |
| `datastore/mysql/k8s_standard/1.0` | mysql | k8s_standard | 1.0 |

### PostgreSQL
Manages PostgreSQL databases across cloud providers and Kubernetes.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `datastore/postgres/aws-aurora/1.0` | postgres | aws-aurora | 1.0 |
| `datastore/postgres/aws-rds/1.0` | postgres | aws-rds | 1.0 |
| `datastore/postgres/azure-flexible-server/1.0` | postgres | azure-flexible-server | 1.0 |
| `datastore/postgres/gcp-cloudsql/1.0` | postgres | gcp-cloudsql | 1.0 |
| `datastore/postgres/k8s_standard/1.0` | postgres | k8s_standard | 1.0 |

### Redis
Manages Redis/cache services across cloud providers and Kubernetes.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `datastore/redis/aws-elasticache/1.0` | redis | aws-elasticache | 1.0 |
| `datastore/redis/azure_cache_custom/1.0` | redis | azure_cache_custom | 1.0 |
| `datastore/redis/gcp-memorystore/1.0` | redis | gcp-memorystore | 1.0 |
| `datastore/redis/k8s_standard/1.0` | redis | k8s_standard | 1.0 |

---

## Core Modules

### Cloud Account
Manages cloud provider configurations and credentials.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/cloud_account/aws_provider/1.0` | cloud_account | aws_provider | 1.0 |
| `modules/cloud_account/azure_provider/1.0` | cloud_account | azure_provider | 1.0 |
| `modules/cloud_account/gcp_provider/1.0` | cloud_account | gcp_provider | 1.0 |

### Kubernetes Cluster
Manages Kubernetes clusters (EKS, AKS, GKE).

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/kubernetes_cluster/aks/1.0` | kubernetes_cluster | aks | 1.0 |
| `modules/kubernetes_cluster/eks/1.0` | kubernetes_cluster | eks | 1.0 |
| `modules/kubernetes_cluster/gke/1.0` | kubernetes_cluster | gke | 1.0 |

### Kubernetes Node Pool
Manages Kubernetes node pools across cloud providers.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/kubernetes_node_pool/aws/1.0` | kubernetes_node_pool | aws | 1.0 |
| `modules/kubernetes_node_pool/azure/1.0` | kubernetes_node_pool | azure | 1.0 |
| `modules/kubernetes_node_pool/gcp_node_fleet/1.0` | kubernetes_node_pool | gcp_node_fleet | 1.0 |
| `modules/kubernetes_node_pool/gcp/1.0` | kubernetes_node_pool | gke_custom_node_pool | 1.0 |

### Network
Manages network infrastructure (VPC, VNet, subnets).

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/network/aws_vpc/1.0` | network | aws_vpc | 1.0 |
| `modules/network/azure_network/1.0` | network | azure_network | 1.0 |
| `modules/network/gcp_vpc/1.0` | network | gcp-vpc | 1.0 |

### Service
Manages application services on Kubernetes across cloud providers.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/service/aws/1.0` | service | aws | 1.0 |
| `modules/service/azure/1.0` | service | azure | 1.0 |
| `modules/service/gcp/1.0` | service | gcp | 1.0 |

### PubSub
Manages pub/sub messaging systems.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/pubsub/gcp/1.0` | pubsub | gcp | 1.0 |

### Workload Identity
Manages workload identity for Kubernetes pods.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/workload_identity/azure/1.0` | azure_workload_identity | azure | 1.0 |
| `modules/workload_identity/gcp/1.0` | google_workload_identity | gcp | 1.0 |

---

## Common Modules

### Artifactories
Manages artifact repositories.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/common/artifactories/standard/1.0` | artifactories | standard | 1.0 |

### Cert Manager
Manages certificate management in Kubernetes.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/common/cert_manager/standard/1.0` | cert_manager | standard | 1.0 |

### Config Map
Manages Kubernetes ConfigMaps.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/common/config_map/k8s_standard/1.0` | config_map | k8s_standard | 1.0 |

### ECK Operator
Manages Elastic Cloud on Kubernetes (ECK) operator.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/common/eck-operator/helm/1.0` | eck-operator | helm | 1.0 |

### Grafana Dashboards
Manages Grafana dashboards in Kubernetes.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/common/grafana_dashboards/k8s/1.0` | grafana_dashboards | k8s | 1.0 |

### Helm
Manages Helm chart deployments.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/common/helm/k8s_standard/1.0` | helm | k8s_standard | 1.0 |

### Ingress
Manages ingress controllers for Kubernetes.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/common/ingress/nginx_k8s/1.0` | ingress | nginx_k8s | 1.0 |

### K8s Callback
Manages Kubernetes callback operations.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/common/k8s_callback/k8s_standard/1.0` | k8s_callback | k8s_standard | 1.0 |

### K8s Resource
Manages generic Kubernetes resources.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/common/k8s_resource/k8s_standard/1.0` | k8s_resource | k8s_standard | 1.0 |

### KubeBlocks CRD
Manages KubeBlocks Custom Resource Definitions.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/common/kubeblocks-crd/standard/1.0` | kubeblocks-crd | standard | 1.0 |

### KubeBlocks Operator
Manages KubeBlocks operator for database management.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/common/kubeblocks-operator/standard/1.0` | kubeblocks-operator | standard | 1.0 |

### Kubernetes Secret
Manages Kubernetes Secrets.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/common/kubernetes_secret/k8s_standard/1.0` | kubernetes_secret | k8s_standard | 1.0 |

### Prometheus
Manages Prometheus monitoring stack.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/common/prometheus/k8s_standard/1.0` | prometheus | k8s_standard | 1.0 |

### Strimzi Operator
Manages Strimzi Kafka operator for Kubernetes.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/common/strimzi-operator/helm/1.0` | strimzi-operator | helm | 1.0 |

### VPA
Manages Vertical Pod Autoscaler.

| Path | Intent | Flavor | Version |
|------|--------|--------|---------|
| `modules/common/vpa/standard/1.0` | vpa | standard | 1.0 |

---

## Summary by Intent

| Intent | Count | Cloud Flavors |
|--------|-------|---------------|
| **kafka** | 2 | AWS, GCP |
| **kafka_topic** | 1 | GCP |
| **mongo** | 3 | AWS DocumentDB, Azure CosmosDB, K8s |
| **mysql** | 5 | AWS Aurora, AWS RDS, Azure Flexible, GCP CloudSQL, K8s |
| **postgres** | 5 | AWS Aurora, AWS RDS, Azure Flexible, GCP CloudSQL, K8s |
| **redis** | 4 | AWS ElastiCache, Azure Cache, GCP Memorystore, K8s |
| **cloud_account** | 3 | AWS, Azure, GCP |
| **kubernetes_cluster** | 3 | EKS, AKS, GKE |
| **kubernetes_node_pool** | 4 | AWS, Azure, GCP (2 variants) |
| **network** | 3 | AWS VPC, Azure VNet, GCP VPC |
| **service** | 3 | AWS, Azure, GCP |
| **pubsub** | 1 | GCP |
| **workload_identity** | 2 | Azure, GCP |
| **Common/Utilities** | 15 | Various K8s and standard flavors |

---

## Module Categories

### Multi-Cloud Support (AWS, Azure, GCP)
- Cloud Account (3)
- Kubernetes Cluster (3)
- Kubernetes Node Pool (4)
- Network (3)
- Service (3)
- MySQL (5 including K8s)
- PostgreSQL (5 including K8s)
- Redis (4 including K8s)
- MongoDB (3 including K8s)

### Cloud-Specific
- **AWS Only:** Kafka (MSK)
- **GCP Only:** PubSub, Kafka Topic
- **Azure & GCP:** Workload Identity

### Kubernetes-Native
All common modules (15 modules) are designed for Kubernetes environments.

---

**Generated:** 2025-12-19  
**Repository:** facets-modules-redesign
