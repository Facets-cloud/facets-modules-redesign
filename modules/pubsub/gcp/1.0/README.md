# GCP Pub/Sub Module

**Version:** 1.0
**Flavor:** gcp
**Intent:** pubsub

## Overview

This module creates a single GCP Pub/Sub topic with an optional pull subscription. It exposes IAM role bindings for Workload Identity integration, enabling Kubernetes services to publish and subscribe to topics using GCP service account permissions. The module follows a single-topic-per-resource design pattern, making it ideal for Template Inputs to create multiple topic instances from a single configuration template.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           GCP Project                                   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │                    Pub/Sub Module (Single Topic)                 │  │
│  │                                                                  │  │
│  │   ┌──────────────────────────────────────────────────────┐     │  │
│  │   │  Topic: payment-events                               │     │  │
│  │   │  Retention: 604800s (7 days)                         │     │  │
│  │   │  Labels: {instance_name, managed_by, env_tags}       │     │  │
│  │   └──────────────────────────────────────────────────────┘     │  │
│  │                          │                                       │  │
│  │                          │ (optional)                            │  │
│  │                          ▼                                       │  │
│  │   ┌──────────────────────────────────────────────────────┐     │  │
│  │   │  Subscription: payment-events-sub                    │     │  │
│  │   │  Ack Deadline: 10s                                    │     │  │
│  │   └──────────────────────────────────────────────────────┘     │  │
│  │                                                                  │  │
│  └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  Module Outputs:                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │ attributes:                                                      │  │
│  │   publisher_role: "roles/pubsub.publisher"                      │  │
│  │   subscriber_role: "roles/pubsub.subscriber"                    │  │
│  │   project_id: "my-gcp-project"                                  │  │
│  │                                                                  │  │
│  │ interfaces.default:                                              │  │
│  │   topic_name: "payment-events"                                  │  │
│  │   topic_id: "projects/.../topics/payment-events"                │  │
│  │   subscription_name: "payment-events-sub"                       │  │
│  │   subscription_id: "projects/.../subscriptions/..."             │  │
│  └─────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
           ▲                                        ▲
           │ publish                                │ subscribe
           │                                        │
┌──────────┴─────────┐                  ┌──────────┴─────────┐
│  Publisher Service │                  │ Subscriber Service │
│  ┌──────────────┐  │                  │  ┌──────────────┐  │
│  │ K8s Pod      │  │                  │  │ K8s Pod      │  │
│  │              │  │                  │  │              │  │
│  │ SA: pub-sa   │  │                  │  │ SA: sub-sa   │  │
│  └──────────────┘  │                  │  └──────────────┘  │
│         │          │                  │         │          │
│         │ Workload Identity           │         │ Workload Identity
│         ▼          │                  │         ▼          │
│  ┌──────────────┐  │                  │  ┌──────────────┐  │
│  │ GCP SA       │  │                  │  │ GCP SA       │  │
│  │ + publisher  │  │                  │  │ + subscriber │  │
│  │   role       │  │                  │  │   role       │  │
│  └──────────────┘  │                  │  └──────────────┘  │
└────────────────────┘                  └────────────────────┘

Dollar Notation References:
  ${pubsub.payment-events.out.attributes.publisher_role}
  ${pubsub.payment-events.out.default.topic_name}
```

## Environment Awareness

The module applies environment-specific metadata through cloud tags. All resources receive standard Facets platform tags that include environment context, enabling resource tracking and cost attribution across deployment targets. The module does not alter topic configuration based on environment, ensuring consistent Pub/Sub behavior across dev, staging, and production.

## Resources Created

This module provisions the following GCP resources:

- **Pub/Sub Topic**: A single topic with configurable message retention
- **Pub/Sub Subscription** (optional): A pull subscription attached to the topic with configurable acknowledgment deadline
- **Resource Labels**: Standard Facets tags including instance name and managed_by metadata

## Output Structure

The module exposes two distinct output categories designed for different integration patterns:

### Attributes (Shared Metadata)

These values remain consistent across all Pub/Sub topic instances and are typically referenced once at the service level:

- `publisher_role`: GCP IAM role for publishing messages (`roles/pubsub.publisher`)
- `subscriber_role`: GCP IAM role for subscribing to topics (`roles/pubsub.subscriber`)
- `project_id`: GCP project where the topic exists

### Interfaces (Connection Details)

The `default` interface provides topic-specific connection information:

- `topic_name`: The fully-qualified topic name
- `topic_id`: The GCP resource ID for the topic
- `project_id`: The GCP project ID
- `subscription_name`: Name of the subscription (if created)
- `subscription_id`: GCP resource ID for the subscription (if created)

## Integration with Services

Services reference Pub/Sub outputs using dollar notation expressions:

- IAM roles: `${pubsub.payment-events.out.attributes.publisher_role}`
- Topic details: `${pubsub.payment-events.out.default.topic_name}`

The module's output structure supports Kubernetes Workload Identity binding, allowing services to authenticate to Pub/Sub using GCP service accounts mapped to Kubernetes service accounts.

## Template Inputs Support

This module's single-topic design enables efficient multi-instance deployments through Facets Template Inputs. A single Mustache template can generate hundreds of topic resources by parameterizing the topic name and metadata. This pattern eliminates the need to manually create individual resource files for each topic, making it ideal for multi-tenant architectures or microservice patterns where each service requires its own topic.

## Configuration Options

### Topic Name

The topic name defaults to the resource instance name but can be overridden via the `topic_name` spec field. This flexibility supports naming conventions that differ from resource identifiers.

### Message Retention

Topics retain unacknowledged messages for a configurable duration (default: 7 days). The retention period must be specified in seconds format (e.g., `604800s`). Longer retention provides better durability guarantees but increases storage costs.

### Subscription Creation

By default, the module creates a pull subscription alongside the topic. This behavior can be disabled by setting `create_subscription` to false. Services that only publish messages typically disable subscription creation to avoid unused resources.

### Acknowledgment Deadline

When subscriptions are enabled, the acknowledgment deadline controls how long Pub/Sub waits for subscriber confirmation before redelivering messages. The deadline must be between 10 and 600 seconds, with a default of 10 seconds.

## Security Considerations

### IAM Role Bindings

The module outputs standard GCP IAM roles rather than creating custom roles. Services must bind these roles to their Workload Identity service accounts to authorize Pub/Sub operations. The platform administrator typically manages these bindings at the cluster or namespace level.

### Workload Identity Integration

GCP Pub/Sub requires authenticated access. This module assumes Workload Identity is configured, allowing Kubernetes pods to assume GCP service account permissions without storing credentials. The service module consumes the `publisher_role` and `subscriber_role` outputs to configure the appropriate bindings.

### Message Encryption

All Pub/Sub messages are encrypted at rest by default using Google-managed encryption keys. The module does not currently support customer-managed encryption keys (CMEK). Organizations requiring CMEK must extend the module to include KMS key references.

## Design Rationale

### Single Topic Per Resource

This module creates exactly one topic per resource instance. Multi-topic configurations require multiple resource instances. This design decision simplifies dollar notation references and aligns with Facets' resource modeling principles, where each resource represents a single infrastructure component.

### Separate Attributes and Interfaces

The output structure splits IAM roles (attributes) from connection details (interfaces). This separation reflects different consumption patterns: IAM roles are referenced once when configuring service accounts, while connection details are referenced per-service for runtime configuration.

### Optional Subscription

Many Pub/Sub deployments use separate subscriber services from publishers. Making subscriptions optional avoids creating unused resources and clarifies the architectural intent when a topic is only used for publishing.
