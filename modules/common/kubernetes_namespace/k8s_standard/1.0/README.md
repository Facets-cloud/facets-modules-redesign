# Kubernetes Namespace Module (k8s_standard)

## Overview

Creates one Kubernetes namespace. It's made for dependent (preview) environments on projects with no environment-level namespace: each preview gets its own namespace, and the services connected to it deploy there instead of into the base environment's namespace.

## How to use it

1. Add one `kubernetes_namespace` resource to the blueprint, **switched off**. The base environment is untouched.
2. Connect the `namespace` input of each service that a preview will dedicate to this resource. A service whose input points at a switched-off resource keeps using the environment namespace.
3. Create the preview with this resource dedicated, e.g. `raptor create environment eph-feature-foo -p P --base-env dev --dedicated kubernetes_namespace/app --dedicated service/api`. The preview gets namespace `eph-feature-foo`, and its `api` runs there.
4. Destroying the preview deletes the namespace and everything in it.

## Configurability

- **`name`** (per environment only, can't be changed after creation): leave it empty to use the environment name. The derived name is lower-cased, invalid characters become `-`, and it's cut to 63 characters. Renaming would replace the namespace and delete everything in it, so the field is locked after creation.
- If the name equals the namespace the platform already gives the environment (dependent environments on the pod-based release path), the module doesn't create it again and only passes the name on.
- Labels: `app.kubernetes.io/managed-by=facets` and `facets.cloud/environment=<env>`, so leftover namespaces can be found.
- Delete timeout is 15 minutes. If teardown fails on a namespace stuck in `Terminating`, check its finalizers (`kubectl get ns <name> -o yaml`).

## Limitations

- **Only services follow the namespace input.** ConfigMaps, Secrets, PVCs and registry pull secrets (`artifactories`) stay in the environment namespace, so a preview service can't mount them or pull private images through them. Add the same optional input to those modules when needed.
- **Don't switch this resource on in a base environment.** Every connected service would move into the new namespace: Helm releases are replaced and stateful-set volumes are recreated empty.
- Keep one namespace resource with an empty name per environment. Two would derive the same name and collide.
- Namespaces are cluster-wide. Preview names must be unique across projects that share a cluster.
- The `kubernetes_namespace/import` flavor (adopting existing namespaces) has a different output type and can't be connected to the service input.

## Inputs

- **Kubernetes Cluster** (`@facets/kubernetes-details`): kubernetes provider

## Outputs

- `@facets/kubernetes_namespace`: `attributes.name`
