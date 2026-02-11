# Facets Module Repository

## Repository Structure

```
modules/{intent}/{flavor}/{version}/   - Core infrastructure modules
datastore/{tech}/{flavor}/{version}/   - Database modules
outputs/{type-name}/                   - Output type schemas (@facets/*)
```

## Module Files

| File | Purpose |
|------|---------|
| `facets.yaml` | Module definition (spec schema, inputs, outputs, sample) |
| `variables.tf` | `var.instance` (spec) and `var.inputs` (dependencies) |
| `main.tf` | Terraform resources |
| `locals.tf` | `output_attributes` and `output_interfaces` |
| `outputs.tf` | Terraform outputs |

## Raptor Commands

```bash
# Validate module (always start with this)
raptor create iac-module -f <module-path> --dry-run

# If security scan fails, retry with skip (but report findings to user)
raptor create iac-module -f <module-path> --dry-run --skip-security-scan

# Upload after validation passes
raptor create iac-module -f <module-path>
```

## Finding Module Standards

Look for `*_module_standard*.md` in the relevant directory:
- `modules/service/` → `service_module_standard.md`
- `modules/network/` → `network_module_standard.md`
- `modules/cloud_account/` → `cloud_account_module_standard.md`
- `modules/kubernetes_node_pool/` → `kubernetes_node_pool_module_standard.md`
- `modules/workload_identity/` → `workload_identity_module_standard.md`
- `datastore/` → `datastore_module_standards.md`

## Validation Rules

See **rules.md** for complete validation ruleset with good/bad examples.

## Icons & Dependency Graph (Review Pages)

```bash
# Start local server to view icon catalog and dependency graph
cd icons && python3 -m http.server 8765

# Then open:
#   http://localhost:8765/index.html   - Icon catalog with flavors/clouds per intent
#   http://localhost:8765/graph.html   - Interactive module dependency graph (search, filter, click nodes)
#   http://localhost:8765/wiring.html  - Attribute-level wiring explorer (inputs/outputs/types/attributes)
```

## Provider-Exposing Module Output Convention

Modules that expose Terraform providers with cloud-specific implementations (e.g., `kubernetes_cluster`) **must** follow this output structure:

| Output Key | Type | Providers | Purpose |
|------------|------|-----------|---------|
| `default` | Cloud-specific (e.g., `@facets/eks`, `@facets/gke`, `@facets/azure_aks`) | None | All cloud-specific attributes (OIDC, node roles, ARNs, etc.) |
| `attributes` | Generic (e.g., `@facets/kubernetes-details`) | Yes (kubernetes, helm, etc.) | Common attributes + provider configuration |

**Why:** Consuming modules that only need kubernetes/helm providers wire to the generic type (`@facets/kubernetes-details`), making them cloud-agnostic. Modules needing cloud-specific details (OIDC provider ARN, node IAM role) wire to the cloud-specific default type.

**Example (kubernetes_cluster):**
```yaml
outputs:
  default:
    type: '@facets/eks'                    # Cloud-specific, NO providers
    title: EKS Cluster Attributes
  attributes:
    type: '@facets/kubernetes-details'     # Generic, WITH providers
    title: Kubernetes Cluster Output
    providers:
      kubernetes:
        source: hashicorp/kubernetes
        version: 2.38.0
        attributes:
          host: attributes.cluster_endpoint
          cluster_ca_certificate: attributes.cluster_ca_certificate
          ...
```

**Applies to:** `kubernetes_cluster/*`, and any future intent where multiple cloud flavors expose a common provider set.

## Behavior Guidelines

- **NEVER** auto-skip validation - always report issues to user
- Report security scan results in **table format**
- Branch naming: `fix/<issue-number>-<short-description>`
- If provider issues (aws3tooling, facets provider), **report to user**
- **NEVER** use `--skip-validation` flag
