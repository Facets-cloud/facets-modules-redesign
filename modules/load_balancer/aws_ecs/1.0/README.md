# AWS ECS Load Balancer

Creates an HTTPS Application Load Balancer and forwards typed ECS service rules to
target groups. The ACM certificate is supplied as a spec reference so certificate
ownership remains separate from load-balancer ownership.

The module emits `@facets/ecs-load-balancer` with the ALB ARN, DNS name, and zone.
