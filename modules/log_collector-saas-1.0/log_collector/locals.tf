locals {
  advanced         = lookup(var.instance, "advanced", {})
  loki_flavor      = lookup(local.advanced, "loki", {})
  loki_helm        = lookup(local.loki_flavor, "loki", {})
  loki             = lookup(local.loki_helm, "values", {})
  promtail_helm    = lookup(local.loki_flavor, "promtail", {})
  promtail         = lookup(local.promtail_helm, "values", {})
  minio_helm       = lookup(local.loki_flavor, "minio", {})
  minio            = lookup(local.minio_helm, "values", {})
  loki_canary_helm = lookup(local.loki_flavor, "loki_canary", {})
  loki_canary      = lookup(local.loki_canary_helm, "values", {})
  spec             = lookup(var.instance, "spec", {})
  loki_namespace   = lookup(local.promtail_helm, "namespace", "facets")
  instance_name    = lower(var.instance_name)

  loki_config            = lookup(local.loki, "loki", {})
  loki_structured_config = lookup(local.loki_config, "structuredConfig", {})
  loki_storage_config    = lookup(local.loki_config, "storageConfig", lookup(local.loki_structured_config, "storage_config", {}))
  azure_storage_config   = lookup(local.loki_storage_config, "azure", {})
  gcs_storage_config     = lookup(local.loki_storage_config, "gcs", {})
  aws_storage_config     = lookup(local.loki_storage_config, "aws", lookup(local.loki_storage_config, "s3", {}))
  is_minio_disabled      = length(local.azure_storage_config) > 0 || length(local.gcs_storage_config) > 0 || length(local.aws_storage_config) > 0

  minio_replicas = lookup(lookup(local.minio, "statefulset", {}), "replicaCount", 4)
  minio_username = "loki_user"
  minio_password = null
  minio_bucket   = "loki"
  minio_endpoint = "${local.instance_name}-minio.${local.loki_namespace}.svc.cluster.local:9000"
  loki_endpoint  = "${local.instance_name}-loki-distributed-gateway.${local.loki_namespace}.svc.cluster.local"
  default_annotations = {
    "facets.cloud/exclude-scale-down" = "true"
  }
  metadata = lookup(var.instance, "metadata", {})
  annotations = merge(local.default_annotations, lookup(local.metadata, "annotations", {}))

  user_defined_loki_helm_values = local.loki
  constructed_loki_helm_values  = local.default_loki

  pipeline_stages = {
    config = {
      snippets = {
        pipelineStages = concat(
          local.default_promtail.config.snippets.pipelineStages,
          lookup(lookup(lookup(local.promtail, "config", {}), "snippets", {}), "pipelineStages", [])
        )
      }
    }
  }

  user_defined_promtail_helm_values = local.promtail
  constructed_promtail_helm_values  = local.default_promtail

  user_defined_minio_helm_values = local.minio
  constructed_minio_helm_values  = local.default_minio
  derived_fields                 = values(lookup(local.loki_flavor, "derived_fields", {}))
  query_timeout                  = lookup(local.loki_flavor, "query_timeout", 60)

  facets_tolerations = concat(lookup(var.environment, "default_tolerations", [{
    key      = "kubernetes.azure.com/scalesetpriority"
    value    = "spot"
    operator = "Equal"
    effect   = "NoSchedule"
  }]), try(var.inputs.kubernetes_details.attributes.legacy_outputs.facets_dedicated_tolerations, []))
  record_type = var.environment.cloud == "AWS" ? "CNAME" : "A"

}
