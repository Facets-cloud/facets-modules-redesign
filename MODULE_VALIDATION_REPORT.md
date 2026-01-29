# Facets Module Validation Report

**Generated**: 2026-01-29

**Repository**: facets-modules-redesign

**Validation Method**: `raptor create iac-module --dry-run` (without skip-validation)

---

## 📊 Executive Summary

**Total Modules Tested**: 61

**Passed**: 26 ✅

**Failed**: 35 ❌

**Success Rate**: 42.6%

### Success Rate by Category

| Category | Total | Passed | Failed | Success Rate |
|----------|-------|--------|--------|-------------|
| cloud_account | 3 | 3 | 0 | 100.0% |
| common | 19 | 5 | 14 | 26.3% |
| datastore | 20 | 15 | 5 | 75.0% |
| karpenter | 1 | 0 | 1 | 0.0% |
| kubernetes_cluster | 4 | 0 | 4 | 0.0% |
| kubernetes_node_pool | 5 | 1 | 4 | 20.0% |
| network | 3 | 1 | 2 | 33.3% |
| pubsub | 1 | 1 | 0 | 100.0% |
| service | 3 | 0 | 3 | 0.0% |
| workload_identity | 2 | 0 | 2 | 0.0% |

---

## 🔍 Detailed Module Results

All 61 modules are listed below with their validation status and error details.

### 1. cloud_account/aws_provider/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/cloud_account/aws_provider/1.0`
- **Validation**: All checks passed

### 2. cloud_account/azure_provider/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/cloud_account/azure_provider/1.0`
- **Validation**: All checks passed

### 3. cloud_account/gcp_provider/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/cloud_account/gcp_provider/1.0`
- **Validation**: All checks passed

### 4. common/artifactories/standard/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/common/artifactories/standard/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 4 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - ecr-token-refresher.tf:3 - "github.com/Facets-cloud/facets-utility-modules//name"
  - registry_secret.tf:3 - "github.com/Facets-cloud/facets-utility-modules//name"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 5. common/cert_manager/standard/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/common/cert_manager/standard/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 10 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:4 - "github.com/Facets-cloud/facets-utility-modules//name"
  - main.tf:15 - "github.com/Facets-cloud/facets-utility-modules//name"
  - main.tf:143 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  - main.tf:184 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  - main.tf:220 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 6. common/config_map/k8s_standard/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/common/config_map/k8s_standard/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 2 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:10 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 7. common/eck-operator/helm/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/common/eck-operator/helm/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.helm_values' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.helm_values: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 8. common/grafana_dashboards/k8s/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/common/grafana_dashboards/k8s/1.0`
- **Validation**: All checks passed

### 9. common/helm/k8s_standard/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/common/helm/k8s_standard/1.0`
- **Validation**: All checks passed

### 10. common/ingress/nginx_k8s/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/common/ingress/nginx_k8s/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 6 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:791 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  - main.tf:806 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  - main.tf:821 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 11. common/k8s_access_controls/k8s_standard/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/common/k8s_access_controls/k8s_standard/1.0`
- **Validation**: All checks passed

### 12. common/k8s_callback/k8s_standard/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/common/k8s_callback/k8s_standard/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: terraform validate failed: terraform validation failed with 4 error(s)
Usage:
  raptor create iac-module [flags]

Flags:
  -a, --auto-create                Automatically create intent if it doesn't exist (default: false)
      --description string         Module description (optional)
      --dry-run                    Run all validations without uploading (ignores all skip flags, default: false)
  -f, --file string                Path to module directory or ZIP file (required)
      --flavor string              Module flavor (overrides facets.yaml)
  -h, --help                       help for iac-module
      --publish                    Publish module immediately after upload (default: false)
      --skip-cleanup               Skip cleanup of temporary files for inspection (default: false)
      --skip-output-write          Skip output processing and file generation (default: false)
      --skip-remote-module-check   Skip validation of remote module re
```

</details>

### 13. common/k8s_resource/k8s_standard/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/common/k8s_resource/k8s_standard/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 6 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:17 - "github.com/Facets-cloud/facets-utility-modules//name"
  - main.tf:26 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  - main.tf:37 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resources"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 14. common/kubeblocks-crd/standard/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/common/kubeblocks-crd/standard/1.0`
- **Validation**: All checks passed

### 15. common/kubeblocks-operator/standard/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/common/kubeblocks-operator/standard/1.0`
- **Validation**: All checks passed

### 16. common/kubernetes_secret/k8s_standard/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/common/kubernetes_secret/k8s_standard/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 2 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:5 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 17. common/monitoring/mongo/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/common/monitoring/mongo/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.additional_helm_values' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.additional_helm_values: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 18. common/prometheus/k8s_standard/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/common/prometheus/k8s_standard/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 6 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:2 - "github.com/Facets-cloud/facets-utility-modules//name"
  - pvc.tf:3 - "github.com/Facets-cloud/facets-utility-modules//pvc"
  - pvc.tf:16 - "github.com/Facets-cloud/facets-utility-modules//pvc"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 19. common/strimzi-operator/helm/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/common/strimzi-operator/helm/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.helm_values' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.helm_values: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 20. common/vpa/standard/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/common/vpa/standard/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.recommender.configuration' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.recommender.configuration: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 21. common/wireguard-operator/standard/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/common/wireguard-operator/standard/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.values' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.values: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 22. common/wireguard-vpn/standard/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/common/wireguard-vpn/standard/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 2 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:50 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 23. datastore/kafka/aws-msk/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/datastore/kafka/aws-msk/1.0`
- **Validation**: All checks passed

### 24. datastore/kafka/gcp-msk/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/datastore/kafka/gcp-msk/1.0`
- **Validation**: All checks passed

### 25. datastore/kafka_topic/gcp-msk/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/datastore/kafka_topic/gcp-msk/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.configs' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.configs: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 26. datastore/mongo/aws-documentdb/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/datastore/mongo/aws-documentdb/1.0`
- **Validation**: All checks passed

### 27. datastore/mongo/cosmosdb/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/datastore/mongo/cosmosdb/1.0`
- **Validation**: All checks passed

### 28. datastore/mongo/kubeblocks/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/datastore/mongo/kubeblocks/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 6 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:10 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  - main.tf:164 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  - main.tf:291 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 29. datastore/mysql/aws-aurora/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/datastore/mysql/aws-aurora/1.0`
- **Validation**: All checks passed

### 30. datastore/mysql/aws-rds/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/datastore/mysql/aws-rds/1.0`
- **Validation**: All checks passed

### 31. datastore/mysql/flexible_server/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/datastore/mysql/flexible_server/1.0`
- **Validation**: All checks passed

### 32. datastore/mysql/gcp-cloudsql/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/datastore/mysql/gcp-cloudsql/1.0`
- **Validation**: All checks passed

### 33. datastore/mysql/kubeblocks/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/datastore/mysql/kubeblocks/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 2 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:10 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 34. datastore/postgres/aws-aurora/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/datastore/postgres/aws-aurora/1.0`
- **Validation**: All checks passed

### 35. datastore/postgres/aws-rds/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/datastore/postgres/aws-rds/1.0`
- **Validation**: All checks passed

### 36. datastore/postgres/azure-flexible-server/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/datastore/postgres/azure-flexible-server/1.0`
- **Validation**: All checks passed

### 37. datastore/postgres/gcp-cloudsql/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/datastore/postgres/gcp-cloudsql/1.0`
- **Validation**: All checks passed

### 38. datastore/postgres/kubeblocks/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/datastore/postgres/kubeblocks/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 2 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:10 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 39. datastore/redis/aws-elasticache/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/datastore/redis/aws-elasticache/1.0`
- **Validation**: All checks passed

### 40. datastore/redis/azure_cache_custom/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/datastore/redis/azure_cache_custom/1.0`
- **Validation**: All checks passed

### 41. datastore/redis/gcp-memorystore/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/datastore/redis/gcp-memorystore/1.0`
- **Validation**: All checks passed

### 42. datastore/redis/kubeblocks/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/datastore/redis/kubeblocks/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 2 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:10 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 43. karpenter/default/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/karpenter/default/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.tags' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.tags: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 44. kubernetes_cluster/aks/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/kubernetes_cluster/aks/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.tags' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.tags: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 45. kubernetes_cluster/eks_automode/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/kubernetes_cluster/eks_automode/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 2 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:2 - "github.com/Facets-cloud/facets-utility-modules//name"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 46. kubernetes_cluster/eks_standard/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/kubernetes_cluster/eks_standard/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.cluster_tags' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.cluster_tags: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 47. kubernetes_cluster/gke/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/kubernetes_cluster/gke/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 2 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:2 - "github.com/Facets-cloud/facets-utility-modules//name"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 48. kubernetes_node_pool/aws/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/kubernetes_node_pool/aws/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 4 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:3 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  - main.tf:18 - "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 49. kubernetes_node_pool/azure/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/kubernetes_node_pool/azure/1.0`
- **Validation**: All checks passed

### 50. kubernetes_node_pool/gcp/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/kubernetes_node_pool/gcp/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 2 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:2 - "github.com/Facets-cloud/facets-utility-modules//name"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 51. kubernetes_node_pool/gcp_node_fleet/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/kubernetes_node_pool/gcp_node_fleet/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.labels' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.labels: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 52. kubernetes_node_pool/karpenter/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/kubernetes_node_pool/karpenter/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.labels' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.labels: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 53. network/aws_network/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/network/aws_network/1.0`
- **Validation**: All checks passed

### 54. network/azure_network/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/network/azure_network/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.tags' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.tags: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 55. network/gcp_network/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/network/gcp_network/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 2 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:2 - "github.com/Facets-cloud/facets-utility-modules//name"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

### 56. pubsub/gcp/1.0 ✅

- **Status**: PASS
- **Module Path**: `modules/pubsub/gcp/1.0`
- **Validation**: All checks passed

### 57. service/aws/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/service/aws/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.env' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.env: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 58. service/azure/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/service/azure/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.env' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.env: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 59. service/gcp/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/service/gcp/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.env' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.env: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 60. workload_identity/azure/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/workload_identity/azure/1.0`
- **Error Type**: Schema Validation (object/map mismatch)
- **Error Summary**: Field 'spec.tags' - expected object, got map

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: var.instance.spec validation failed: var.instance.spec does not match schema defined in facets.yaml: at spec.tags: expected object, got map
Usage:
  raptor create iac-module [flags]


```

</details>

### 61. workload_identity/gcp/1.0 ❌

- **Status**: FAIL
- **Module Path**: `modules/workload_identity/gcp/1.0`
- **Error Type**: Remote Module Reference
- **Error Summary**: 2 remote module reference(s)

<details>
<summary>View Full Error Output</summary>

```
Error: module validation failed: remote module validation failed: remote module references found:
  - main.tf:3 - "github.com/Facets-cloud/facets-utility-modules//name"
Modules should only use local relative paths (e.g., ./modules/submodule)
Usage:
  raptor create iac-module [flags]


```

</details>

---

## 📋 Failure Analysis by Error Type

The 35 failed modules are categorized below by error type.

### Remote Module Reference (19 modules)

| Module | Error Details |
|--------|---------------|
| common/artifactories/standard/1.0 | 4 remote module reference(s) |
| common/cert_manager/standard/1.0 | 10 remote module reference(s) |
| common/config_map/k8s_standard/1.0 | 2 remote module reference(s) |
| common/ingress/nginx_k8s/1.0 | 6 remote module reference(s) |
| common/k8s_callback/k8s_standard/1.0 |  |
| common/k8s_resource/k8s_standard/1.0 | 6 remote module reference(s) |
| common/kubernetes_secret/k8s_standard/1.0 | 2 remote module reference(s) |
| common/prometheus/k8s_standard/1.0 | 6 remote module reference(s) |
| common/wireguard-vpn/standard/1.0 | 2 remote module reference(s) |
| datastore/mongo/kubeblocks/1.0 | 6 remote module reference(s) |
| datastore/mysql/kubeblocks/1.0 | 2 remote module reference(s) |
| datastore/postgres/kubeblocks/1.0 | 2 remote module reference(s) |
| datastore/redis/kubeblocks/1.0 | 2 remote module reference(s) |
| kubernetes_cluster/eks_automode/1.0 | 2 remote module reference(s) |
| kubernetes_cluster/gke/1.0 | 2 remote module reference(s) |
| kubernetes_node_pool/aws/1.0 | 4 remote module reference(s) |
| kubernetes_node_pool/gcp/1.0 | 2 remote module reference(s) |
| network/gcp_network/1.0 | 2 remote module reference(s) |
| workload_identity/gcp/1.0 | 2 remote module reference(s) |

**Root Cause**: Modules reference remote GitHub repositories (`github.com/Facets-cloud/facets-utility-modules`). Raptor validation policy requires all module references to use local relative paths.

**Fix**: Either:
1. Use `--skip-remote-module-check` flag when uploading
2. Vendor the utility modules locally
3. Use `git::` URLs instead of GitHub short syntax

### Schema Validation (object/map mismatch) (16 modules)

| Module | Error Details |
|--------|---------------|
| common/eck-operator/helm/1.0 | Field 'spec.helm_values' - expected object, got map |
| common/monitoring/mongo/1.0 | Field 'spec.additional_helm_values' - expected object, got map |
| common/strimzi-operator/helm/1.0 | Field 'spec.helm_values' - expected object, got map |
| common/vpa/standard/1.0 | Field 'spec.recommender.configuration' - expected object, got map |
| common/wireguard-operator/standard/1.0 | Field 'spec.values' - expected object, got map |
| datastore/kafka_topic/gcp-msk/1.0 | Field 'spec.configs' - expected object, got map |
| karpenter/default/1.0 | Field 'spec.tags' - expected object, got map |
| kubernetes_cluster/aks/1.0 | Field 'spec.tags' - expected object, got map |
| kubernetes_cluster/eks_standard/1.0 | Field 'spec.cluster_tags' - expected object, got map |
| kubernetes_node_pool/gcp_node_fleet/1.0 | Field 'spec.labels' - expected object, got map |
| kubernetes_node_pool/karpenter/1.0 | Field 'spec.labels' - expected object, got map |
| network/azure_network/1.0 | Field 'spec.tags' - expected object, got map |
| service/aws/1.0 | Field 'spec.env' - expected object, got map |
| service/azure/1.0 | Field 'spec.env' - expected object, got map |
| service/gcp/1.0 | Field 'spec.env' - expected object, got map |
| workload_identity/azure/1.0 | Field 'spec.tags' - expected object, got map |

**Root Cause**: The `facets.yaml` schema defines these fields as `type: object` without `additionalProperties`, but the Terraform `variables.tf` defines them as `map(string)`. The raptor validator expects object schema to have explicit `additionalProperties` definition.

**Fix**: Add `additionalProperties` to the facets.yaml schema:
```yaml
field_name:
  type: object
  additionalProperties:
    type: string
```

---

## 🔧 Common Failure Patterns

### Pattern 1: Schema Object vs Map Mismatch
**Affected**: 16 modules

**Fields affected**:
- `spec.additional_helm_values` (1 modules)
- `spec.cluster_tags` (1 modules)
- `spec.configs` (1 modules)
- `spec.env` (3 modules)
- `spec.helm_values` (2 modules)
- `spec.labels` (2 modules)
- `spec.recommender.configuration` (1 modules)
- `spec.tags` (4 modules)
- `spec.values` (1 modules)

### Pattern 2: facets-utility-modules References
**Affected**: 19 modules

All these modules use helper modules from `github.com/Facets-cloud/facets-utility-modules` for common patterns like:
- Resource naming (`//name`)
- Generic Kubernetes resources (`//any-k8s-resource`)
- PVC creation (`//pvc`)

---

## 📊 Final Overview

**Total Modules**: 61

**Passed**: 26 ✅

**Failed**: 35 ❌

**Success Rate**: 42.6%

### ✅ Modules That PASSED Validation

| # | Module | Category |
|---|--------|----------|
| 1 | cloud_account/aws_provider/1.0 | cloud_account |
| 2 | cloud_account/azure_provider/1.0 | cloud_account |
| 3 | cloud_account/gcp_provider/1.0 | cloud_account |
| 4 | common/grafana_dashboards/k8s/1.0 | common |
| 5 | common/helm/k8s_standard/1.0 | common |
| 6 | common/k8s_access_controls/k8s_standard/1.0 | common |
| 7 | common/kubeblocks-crd/standard/1.0 | common |
| 8 | common/kubeblocks-operator/standard/1.0 | common |
| 9 | datastore/kafka/aws-msk/1.0 | datastore |
| 10 | datastore/kafka/gcp-msk/1.0 | datastore |
| 11 | datastore/mongo/aws-documentdb/1.0 | datastore |
| 12 | datastore/mongo/cosmosdb/1.0 | datastore |
| 13 | datastore/mysql/aws-aurora/1.0 | datastore |
| 14 | datastore/mysql/aws-rds/1.0 | datastore |
| 15 | datastore/mysql/flexible_server/1.0 | datastore |
| 16 | datastore/mysql/gcp-cloudsql/1.0 | datastore |
| 17 | datastore/postgres/aws-aurora/1.0 | datastore |
| 18 | datastore/postgres/aws-rds/1.0 | datastore |
| 19 | datastore/postgres/azure-flexible-server/1.0 | datastore |
| 20 | datastore/postgres/gcp-cloudsql/1.0 | datastore |
| 21 | datastore/redis/aws-elasticache/1.0 | datastore |
| 22 | datastore/redis/azure_cache_custom/1.0 | datastore |
| 23 | datastore/redis/gcp-memorystore/1.0 | datastore |
| 24 | kubernetes_node_pool/azure/1.0 | kubernetes_node_pool |
| 25 | network/aws_network/1.0 | network |
| 26 | pubsub/gcp/1.0 | pubsub |

### ❌ Modules That FAILED Validation

Failures are grouped by error type for easier analysis.

#### Remote Module Reference (19 modules)

| # | Module | Specific Error |
|---|--------|----------------|
| 1 | common/artifactories/standard/1.0 | 4 remote module reference(s) |
| 2 | common/cert_manager/standard/1.0 | 10 remote module reference(s) |
| 3 | common/config_map/k8s_standard/1.0 | 2 remote module reference(s) |
| 4 | common/ingress/nginx_k8s/1.0 | 6 remote module reference(s) |
| 5 | common/k8s_callback/k8s_standard/1.0 |  |
| 6 | common/k8s_resource/k8s_standard/1.0 | 6 remote module reference(s) |
| 7 | common/kubernetes_secret/k8s_standard/1.0 | 2 remote module reference(s) |
| 8 | common/prometheus/k8s_standard/1.0 | 6 remote module reference(s) |
| 9 | common/wireguard-vpn/standard/1.0 | 2 remote module reference(s) |
| 10 | datastore/mongo/kubeblocks/1.0 | 6 remote module reference(s) |
| 11 | datastore/mysql/kubeblocks/1.0 | 2 remote module reference(s) |
| 12 | datastore/postgres/kubeblocks/1.0 | 2 remote module reference(s) |
| 13 | datastore/redis/kubeblocks/1.0 | 2 remote module reference(s) |
| 14 | kubernetes_cluster/eks_automode/1.0 | 2 remote module reference(s) |
| 15 | kubernetes_cluster/gke/1.0 | 2 remote module reference(s) |
| 16 | kubernetes_node_pool/aws/1.0 | 4 remote module reference(s) |
| 17 | kubernetes_node_pool/gcp/1.0 | 2 remote module reference(s) |
| 18 | network/gcp_network/1.0 | 2 remote module reference(s) |
| 19 | workload_identity/gcp/1.0 | 2 remote module reference(s) |

#### Schema Validation (object/map mismatch) (16 modules)

| # | Module | Specific Error |
|---|--------|----------------|
| 1 | common/eck-operator/helm/1.0 | Field 'spec.helm_values' - expected object, got map |
| 2 | common/monitoring/mongo/1.0 | Field 'spec.additional_helm_values' - expected object, got map |
| 3 | common/strimzi-operator/helm/1.0 | Field 'spec.helm_values' - expected object, got map |
| 4 | common/vpa/standard/1.0 | Field 'spec.recommender.configuration' - expected object, got map |
| 5 | common/wireguard-operator/standard/1.0 | Field 'spec.values' - expected object, got map |
| 6 | datastore/kafka_topic/gcp-msk/1.0 | Field 'spec.configs' - expected object, got map |
| 7 | karpenter/default/1.0 | Field 'spec.tags' - expected object, got map |
| 8 | kubernetes_cluster/aks/1.0 | Field 'spec.tags' - expected object, got map |
| 9 | kubernetes_cluster/eks_standard/1.0 | Field 'spec.cluster_tags' - expected object, got map |
| 10 | kubernetes_node_pool/gcp_node_fleet/1.0 | Field 'spec.labels' - expected object, got map |
| 11 | kubernetes_node_pool/karpenter/1.0 | Field 'spec.labels' - expected object, got map |
| 12 | network/azure_network/1.0 | Field 'spec.tags' - expected object, got map |
| 13 | service/aws/1.0 | Field 'spec.env' - expected object, got map |
| 14 | service/azure/1.0 | Field 'spec.env' - expected object, got map |
| 15 | service/gcp/1.0 | Field 'spec.env' - expected object, got map |
| 16 | workload_identity/azure/1.0 | Field 'spec.tags' - expected object, got map |

---

## 💡 Recommendations

### Immediate Actions

1. **Fix Schema Validation Issues** (15+ modules)
   - Add `additionalProperties: {type: string}` to object fields in facets.yaml
   - Fields needing fixes: `tags`, `env`, `labels`, `helm_values`, `configs`, etc.

2. **Handle Remote Module References** (15+ modules)
   - Use `--skip-remote-module-check` when uploading these modules
   - OR vendor the utility modules locally

3. **Fix Terraform Validation Errors** (1 module)
   - `common/k8s_callback/k8s_standard/1.0` has Terraform syntax errors

### Publishing Strategy

For modules that can't be fixed immediately, use these flags:
```bash
# For schema validation issues
raptor create iac-module -f <path> --skip-validation

# For remote module references only
raptor create iac-module -f <path> --skip-remote-module-check
```

---

**End of Report**
