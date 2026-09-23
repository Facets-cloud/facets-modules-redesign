# AWS ECS Service

Runs a container image as an ECS Fargate service. Network and cluster references
are structural inputs, while runtime, release, environment, and IAM settings are
blueprint-time spec fields.

The module emits `@facets/ecs-service` with the service ARN and cluster ARN.
