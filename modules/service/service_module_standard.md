# Service Module Standards

These instructions supplement the default Facets module generation guidelines for this repository.

## Repository Scope

This repository contains service modules for deploying workloads on Kubernetes across AWS, Azure, and GCP. Each module represents a unified deployment interface for applications, cronjobs, jobs, and statefulsets.

## Design Philosophy

### Simplicity Over Flexibility
- Provide common deployment patterns with sensible defaults
- Support multiple workload types (application, cronjob, job, statefulset)
- Use production-ready defaults that don't require extensive configuration
- Abstract away complex Kubernetes configurations
- **Focus on developer experience** - make deploying services easy

### Technology-Familiar Field Names
- Use field names familiar to Kubernetes and container users
- Do NOT invent new abstractions for standard K8s concepts
- Make modules configurable by developers who are not Kubernetes experts
- Use industry-standard terminology (pods, containers, health checks, etc.)

### Security-First Defaults
- Enable security contexts by default
- Support cloud IAM integration (IRSA, Workload Identity)
- Implement resource limits and requests by default
- Enable health checks and readiness probes
- Support for secrets and config maps
- Pod security standards compliance

## Module Conventions

### Naming Standards
- **Intent**: Use `service` for all cloud providers
- **Flavors**: Cloud-specific names (e.g., `aws`, `azure`, `gcp`)

- **All outputs and inputs MUST use `@facets/` namespace prefix**
- **STRICTLY FORBIDDEN: Using any output types that do NOT start with `@facets/`**

## Core Functionality Requirements

Every module MUST provide support for:

1. **Workload Types**
   - **application**: Standard Deployment workloads
   - **cronjob**: Scheduled cron-based jobs
   - **job**: One-time or batch processing tasks
   - **statefulset**: Stateful applications with persistent storage

2. **Runtime Configuration**
   - Container resource sizing (CPU, memory, limits)
   - Port mappings and service exposure
   - Health checks (readiness, liveness, startup)
   - Autoscaling (HPA) configuration
   - Command and arguments override
   - Environment variables

3. **Storage**
   - Persistent Volume Claims (for statefulsets)
   - Config Map mounts
   - Secret mounts
   - PVC mounts
   - Host path mounts

4. **Cloud Integration**
   - Cloud IAM permissions (IRSA for AWS, Workload Identity for GCP/Azure)
   - IAM policy attachments
   - Service account configuration

5. **Advanced Features**
   - Init containers
   - Sidecar containers
   - Pod distribution/topology constraints
   - Anti-affinity rules
   - Deployment strategies (RollingUpdate, Recreate)
   - Pod disruption budgets
   - Metrics endpoints (Prometheus integration)

6. **Release Management**
   - Container image management
   - Image pull policies
   - Build artifactory integration
   - Rolling update strategies
   - Disruption policies

## Module Structure

### Required Files
```
service/
  {flavor}/
    1.0/
      ├── facets.yaml          # Must include @facets/ outputs
      ├── main.tf             # Core Terraform resources
      ├── variables.tf        # Must mirror facets.yaml spec structure
      ├── locals.tf           # Local computations and output_attributes
      ├── outputs.tf          # Terraform outputs
      └── README.md           # Generated documentation
```

## CRITICAL: Input Type Management Rules

**NEVER register output types that you need as inputs:**
- ALL required input types MUST already exist in the control plane
- If needed input types don't exist, STOP and clarify with the user first
- Do NOT create missing input types - they must be provided by other modules

## Output Types and Structure

### MANDATORY User Approval for New Output Types
- Get explicit user confirmation before creating ANY new output type
- There is NO blanket approval for output type creation
- Present the output type structure and get approval before proceeding

### Output Naming Convention
- **Default output**: MUST use `@facets/service` for cross-cloud compatibility
  - This standardized output provides service metadata and Kubernetes resources

### Standard Output Structure

```yaml
outputs:
  default:
    type: '@facets/service'
    title: Service Output
    description: Kubernetes service deployment details
```

## Spec Structure

All modules MUST organize their `spec.properties` using **GROUPED OBJECTS**:

**Required Groups:**
- `type`: Workload type selection
- `runtime`: Container runtime configuration (size, ports, health checks, autoscaling, volumes, metrics)
- `release`: Image and deployment strategy configuration
- `env`: Environment variables
- `cloud_permissions`: Cloud IAM integration
- `init_containers`: Init container specifications (optional)
- `sidecars`: Sidecar container specifications (optional)
- `persistent_volume_claims`: PVC configuration for statefulsets (optional)
- `pod_distribution`: Topology spread constraints (optional)
- `cronjob`: Cron schedule configuration (conditional)
- `job`: Job retry configuration (conditional)

### Service Spec Pattern

```yaml
spec:
  type: object
  properties:
    type:
      type: string
      title: Service Type
      enum: [application, cronjob, job, statefulset]
      default: application

    restart_policy:
      type: string
      title: Restart Policy
      enum: [Always, OnFailure, Never]
      x-ui-visible-if:
        field: spec.type
        values: [application, statefulset]

    enable_host_anti_affinity:
      type: boolean
      title: Enable Host Anti-Affinity
      x-ui-visible-if:
        field: spec.type
        values: [application, statefulset]

    pod_distribution_enabled:
      type: boolean
      title: Enable Pod Distribution
      default: false

    pod_distribution:
      type: object
      title: Pod Distribution
      x-ui-toggle: true
      x-ui-visible-if:
        field: spec.pod_distribution_enabled
        values: [true]
      patternProperties:
        ^[a-zA-Z0-9_-]*$:
          type: object
          properties:
            topology_key:
              type: string
              enum: [kubernetes.io/hostname, topology.kubernetes.io/zone, kubernetes.io/arch, lifecycle]
            when_unsatisfiable:
              type: string
              enum: [DoNotSchedule, ScheduleAnyway]
            max_skew:
              type: integer
              minimum: 1
              maximum: 100

    runtime:
      type: object
      title: Runtime
      properties:
        command:
          type: array
          items: {type: string}
        args:
          type: array
          items: {type: string}

        size:
          type: object
          properties:
            cpu: {type: string, pattern: "..."}
            memory: {type: string, pattern: "..."}
            cpu_limit: {type: string}
            memory_limit: {type: string}
          required: [cpu, memory]

        ports:
          type: object
          x-ui-toggle: true
          patternProperties:
            ^[0-9]+[m]?$:
              properties:
                port: {type: string}
                service_port: {type: string}
                protocol: {type: string, enum: [tcp, udp]}

        health_checks:
          type: object
          x-ui-toggle: true
          properties:
            readiness_check_type: {enum: [None, PortCheck, HttpCheck, ExecCheck]}
            liveness_check_type: {enum: [None, PortCheck, HttpCheck, ExecCheck]}
            startup_check_type: {enum: [None, PortCheck, HttpCheck, ExecCheck]}
            # ... conditional fields based on check types

        autoscaling:
          type: object
          x-ui-toggle: true
          properties:
            min: {type: integer, minimum: 1, maximum: 200}
            max: {type: integer, minimum: 1, maximum: 200}
            scaling_on: {enum: [CPU, RAM]}
            cpu_threshold: {type: string}
            ram_threshold: {type: string}

        metrics:
          type: object
          x-ui-toggle: true
          patternProperties:
            ^[a-zA-Z0-9_.-]*$:
              properties:
                path: {type: string}
                port_name: {type: string}

        volumes:
          type: object
          x-ui-toggle: true
          properties:
            config_maps: {...}
            secrets: {...}
            pvc: {...}
            host_path: {...}

      required: [ports, size]

    release:
      type: object
      properties:
        image: {type: string, x-ui-skip: true}
        image_pull_policy: {enum: [IfNotPresent, Always, Never]}
        strategy:
          properties:
            type: {enum: [RollingUpdate, Recreate]}
            max_available: {type: string}
            max_unavailable: {type: string}

    cloud_permissions:
      type: object
      x-ui-toggle: true
      properties:
        aws:  # or azure/gcp depending on cloud
          properties:
            enable_irsa: {type: boolean}
            iam_policies:
              patternProperties:
                ^[a-zA-Z0-9_.-]*$:
                  properties:
                    arn: {type: string}

    env:
      type: object
      title: Environment Variables
      x-ui-yaml-editor: true

    init_containers:
      type: object
      x-ui-toggle: true
      patternProperties:
        ^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$:
          properties:
            image: {type: string}
            pull_policy: {enum: [IfNotPresent, Always, Never]}
            runtime: {...}

    sidecars:
      type: object
      x-ui-toggle: true
      patternProperties:
        ^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$:
          properties:
            image: {type: string}
            pull_policy: {enum: [IfNotPresent, Always, Never]}
            runtime: {...}

  required: [type, runtime]
```

### Allowed Configuration Fields

**These fields ARE acceptable:**
- All workload type configurations
- Container resource sizing and limits
- Health check configurations
- Autoscaling settings
- Storage volume mounts
- Cloud IAM permissions
- Init and sidecar containers
- Pod distribution and affinity rules
- Environment variables

**These fields are FORBIDDEN:**
- Low-level Kubernetes resource specifications
- Direct manipulation of Kubernetes API objects
- Cluster-level configurations
- Network policies (should be separate module)
- Ingress configurations (should be separate module)

## Required Input Types

All service modules MUST consume:

1. **Cloud Account** (MANDATORY):
   - `@facets/aws_cloud_account` (AWS)
   - `@facets/azure_cloud_account` (Azure)
   - `@facets/gcp_cloud_account` (GCP)
   - Must specify provider configurations

2. **Kubernetes Details** (MANDATORY):
   - `@facets/kubernetes-details` or cloud-specific types
   - `@facets/eks` (AWS)
   - `@facets/azure_aks` (Azure)
   - `@facets/gke` (GCP)
   - Must provide kubernetes, helm, and kubernetes-alpha providers

3. **Optional Inputs**:
   - Kubernetes node pool details (for pod placement)
   - Artifactories (for container registries)
   - VPA details (Vertical Pod Autoscaler)

## Artifact Inputs

Service modules MUST support artifact inputs for container images:

```yaml
artifact_inputs:
  primary:
    attribute_path: spec.release.image
    artifact_type: docker_image
```

## Validation Checklist

Before completing any module:
- [ ] Outputs use `@facets/` namespace
- [ ] Default output is `@facets/service`
- [ ] Inputs only consume `@facets/` namespaced types
- [ ] Cloud account and Kubernetes cluster inputs configured
- [ ] All workload types supported (application, cronjob, job, statefulset)
- [ ] Runtime configuration comprehensive
- [ ] Health checks properly configured
- [ ] Storage volume support implemented
- [ ] Cloud IAM integration working
- [ ] Spec uses GROUPED OBJECTS structure
- [ ] Module validates successfully
- [ ] Provider configurations properly reference inputs
- [ ] Artifact inputs configured for container images
