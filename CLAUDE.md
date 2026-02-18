# Facets Module Repository

## Repository Structure

```
modules/{intent}/{flavor}/{version}/   - Core infrastructure modules
modules/datastore/{tech}/{flavor}/{version}/ - Database modules
outputs/{type-name}/                   - Output type schemas (@facets/*)
icons/{intent}.svg                     - Module icons (one per intent, cloud-neutral)
project-type/{cloud}/project-type.yml  - Project type definitions (AWS/GCP/Azure)
index.html                             - User-facing catalog page (GitHub Pages)
app/internal/                          - Internal dev tools (icons, graph, wiring)
```

## Prerequisites

Install the Facets Claude Code plugin for module development workflows, blueprint management, and Raptor CLI skills:

```bash
/plugin marketplace add Facets-cloud/claude-plugin
/plugin install facets-plugin@facets-marketplace
```

Key skills: `/facets-module` (module development), `/blueprint` (blueprint management), `/raptor` (CLI operations)

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

## Internal Dev Tools

```bash
# Start local server from repo root
python3 -m http.server 8765

# Internal pages (not user-facing):
#   http://localhost:8765/app/internal/icons.html   - Icon catalog with flavors/clouds per intent
#   http://localhost:8765/app/internal/graph.html   - Interactive module dependency graph
#   http://localhost:8765/app/internal/wiring.html  - Attribute-level wiring explorer

# User-facing catalog page:
#   http://localhost:8765/index.html
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

## New Module Checklist

When creating a new module, complete ALL of these steps:

### 0. facets.yaml intentDetails (required)
- Every `facets.yaml` must include an `intentDetails` block
- Required fields: `type`, `description`, `displayName`, `iconUrl`
- See RULE-021 in `rules.md` for details and valid `type` values

### 1. Icon (`icons/{intent}.svg`)
- Each **intent** gets one SVG icon (not per flavor)
- Icons MUST be **cloud-neutral** (no AWS/GCP/Azure branding) since intents span multiple clouds
- Place at `icons/{intent}.svg` (e.g., `icons/postgres.svg`, `icons/helm.svg`)
- Use filled SVGs (`fill="#4A5568"` or similar), NOT stroke-only (stroke-only is invisible on some backgrounds)
- Source SVG files from https://vecta.io/symbols — search for the technology name and download the SVG
- If the intent already has an icon, do NOT create a new one

### 2. Project Type (`project-type/{cloud}/project-type.yml`)
- Add the new module entry (intent + flavor) to the relevant cloud's project-type.yml
- AWS: `project-type/aws/project-type.yml`
- GCP: `project-type/gcp/project-type.yml`
- Azure: `project-type/azure/project-type.yml`
- Common modules (K8s platform, operators) go in ALL three project types
- Cloud-specific modules go only in their cloud's project type

### 3. Catalog Page (`index.html`)
- Update the `CLOUD_DATA` JavaScript object with the new module
- Add to the correct cloud (aws/gcp/azure) and correct category
- Categories: Infrastructure, Managed Datastores, Self-hosted via KubeBlocks, K8s Platform, Operators & Monitoring
- Do NOT hardcode module counts — they are computed dynamically

### 4. README (`README.md`)
- Add the new module to the correct cloud section's collapsible "What's included" list
- Use format: `` `DisplayName (flavor)` `` (e.g., `` `PostgreSQL/RDS (aws-rds)` ``)
- Do NOT add module counts — the README is count-free
- Praxis prompts use format "Prompt for Praxis:" with copyable code blocks
- Raptor CLI: base command and `--name` variant are separate copyable blocks

### 5. Internal Pages (if new intent)
- `app/internal/icons.html` — Add entry to the `MODULES` data array with intent, displayName, type, icon filename, flavors/clouds
- `app/internal/graph.html` — Add entry to the `MODULES` data array with id, intent, flavor, displayName, group, clouds, icon, inputs/outputs
- `app/internal/wiring.html` — Data is in `app/internal/wiring-data.json`, update if module has inputs/outputs
- Icon paths in internal pages use `../../icons/{filename}` (relative from `app/internal/`)

## Behavior Guidelines

- **NEVER** auto-skip validation - always report issues to user
- Report security scan results in **table format**
- Branch naming: `fix/<issue-number>-<short-description>`
- If provider issues (aws3tooling, facets provider), **report to user**
- **NEVER** use `--skip-validation` flag

## Rule Discovery

When working on modules (writing, reviewing, or validating), if you notice a recurring pattern, anti-pattern, or convention that is NOT already covered by an existing rule in `rules.md`:
- Flag it to the user with a brief description and a good/bad example
- Propose a new rule following the existing format (RULE-XXX, category, description, bad example, good example)
- Do NOT add the rule to rules.md without user approval
