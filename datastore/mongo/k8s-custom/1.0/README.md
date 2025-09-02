# MongoDB Kubernetes Module (k8s-custom)

[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](https://semver.org)
[![Kubernetes](https://img.shields.io/badge/kubernetes-compatible-green.svg)](https://kubernetes.io/)

## Overview

This module deploys and manages MongoDB database instances on Kubernetes using StatefulSets with secure defaults and high availability support. It provides a developer-friendly interface for MongoDB deployment with production-ready configurations.

## Environment as Dimension

The module is environment-aware and adapts based on the deployment environment:
- **Namespace isolation** - deploys in configurable namespaces per environment
- **Resource scaling** - different CPU/memory allocations per environment
- **Storage requirements** - configurable storage sizes based on environment needs
- **Replica configuration** - supports single instance for development, multi-replica for production
- **Security contexts** - consistent security policies across environments

## Resources Created

- **StatefulSet** - MongoDB database instances with persistent storage
- **Service** - ClusterIP service for internal database connectivity 
- **Secret** - Encrypted storage for MongoDB credentials and configuration
- **ConfigMap** - MongoDB initialization scripts and configuration
- **PersistentVolumeClaims** - Persistent storage volumes for database data

## Security Considerations

This module implements security-first defaults:

- **Encrypted Credentials** - All passwords stored in Kubernetes Secrets
- **Authentication Required** - MongoDB requires authentication for all connections
- **Network Isolation** - ClusterIP service limits access to cluster-internal only
- **Secure Initialization** - Proper user and database setup during deployment
- **Data Protection** - Lifecycle protection prevents accidental data deletion
- **Resource Limits** - CPU and memory limits prevent resource exhaustion

The module automatically generates secure passwords when not explicitly provided and follows MongoDB security best practices for Kubernetes deployments.
