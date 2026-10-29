# ConfigMap — Anycloud (consumer example)

A Kubernetes ConfigMap that runs on any anycloud cluster. A ConfigMap is pure
Kubernetes, so this module needs no AWS or GCP branch. It wires only to
`@facets/kubernetes-details` for the providers. This is the simplest way to
consume an anycloud cluster. See
[`modules/ANYCLOUD_PATTERN.md`](../../../ANYCLOUD_PATTERN.md).

- **Clouds:** aws, gcp
- **Input:** `kubernetes_cluster` → `@facets/kubernetes-details` (kubernetes, helm providers)
- **Output type:** `@facets/any_cloud_config_map` (`config_map_name`, `namespace`, `data_keys`, `cloud_provider`)

## Usage

```yaml
kind: config_map
flavor: anycloud
version: "1.0"
spec:
  namespace: app
  create_namespace: true
  data:
    app.yaml:
      content: |
        log_level: info
```

## Notes

- **The namespace is created but never owned.** A no-op Helm release with
  `create_namespace = true` creates a missing namespace and abandons it, so
  removing this ConfigMap never deletes a shared namespace.
- **Keys are filenames.** Each `spec.data` key is the ConfigMap key, and the
  filename when it is mounted with `subPath`.
