# Kubernetes Service

Cloud-agnostic service module for deploying containerized workloads on any Kubernetes cluster (including LKE, GKE, EKS, AKS, OVH MKS). Produces the `@facets/service` output type.

## Overview

A unified deployment interface supporting `application` (Deployment), `cronjob`, `job`, and `statefulset` workloads. It consumes the Kubernetes and Helm providers from a `@facets/kubernetes-details` input, so it has no cloud-specific logic — it runs the same on every cluster. There is no cloud IAM/workload-identity wiring (Kubernetes-native service accounts only); use cloud-specific service flavors when pod-level cloud IAM is required.

## Features

- Workload types: application, cronjob, job, statefulset
- Resource sizing (CPU/memory requests + limits), health checks, autoscaling (HPA)
- Environment variables, secrets, config maps, persistent volume claims
- Container registry (artifactories) and optional VPA integration

## Inputs

- **Kubernetes Cluster** (`@facets/kubernetes-details`): k8s + helm providers
- **Node Pool** (`@facets/kubernetes_nodepool`)
- **Container Registries** (`@facets/artifactories`, optional)
- **Vertical Pod Autoscaler** (`@facets/vpa`, optional)

## Outputs

- `@facets/service`
