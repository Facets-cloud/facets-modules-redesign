# using random_password resource instead of utility/password since minio password has regex constraint [\w+=,.@-]+
resource "random_password" "minio_password" {
  count            = local.is_minio_disabled ? 0 : 1
  length           = 16
  special          = true
  override_special = "+=,.@-"
}

module "ingester-pvc" {
  count             = local.ingester_pvc_enabled ? local.ingester_replicas : 0
  source            = "github.com/Facets-cloud/facets-utility-modules//pvc"
  name              = "data-${local.instance_name}-loki-distributed-ingester-${count.index}"
  namespace         = local.loki_namespace
  access_modes      = ["ReadWriteOnce"]
  volume_size       = local.ingester_pvc_size
  provisioned_for   = "${local.instance_name}-loki-distributed-ingester-${count.index}"
  instance_name     = local.instance_name
  kind              = "log_collector"
  additional_labels = lookup(lookup(local.loki_helm_values, "ingester", {}), "pvc_labels_ingester", {})
  cloud_tags        = var.environment.cloud_tags
}

module "querier-pvc" {
  count             = local.querier_pvc_enabled ? local.querier_replicas : 0
  source            = "github.com/Facets-cloud/facets-utility-modules//pvc"
  name              = "data-${local.instance_name}-loki-distributed-querier-${count.index}"
  namespace         = local.loki_namespace
  access_modes      = ["ReadWriteOnce"]
  volume_size       = local.querier_pvc_size
  provisioned_for   = "${local.instance_name}-loki-distributed-querier-${count.index}"
  instance_name     = local.instance_name
  kind              = "log_collector"
  additional_labels = lookup(lookup(local.loki_helm_values, "querier", {}), "pvc_labels_querier", {})
  cloud_tags        = var.environment.cloud_tags
}

resource "helm_release" "loki" {
  depends_on       = [helm_release.minio, module.ingester-pvc, module.querier-pvc]
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-distributed"
  name             = local.instance_name
  cleanup_on_fail  = true
  create_namespace = true
  timeout          = lookup(local.loki_helm_values, "timeout", 600)
  wait             = lookup(local.loki_helm_values, "wait", true)
  recreate_pods    = lookup(local.loki_helm_values, "recreate_pods", false)
  version          = lookup(local.loki_helm_values, "version", "0.69.0")
  namespace        = local.loki_namespace
  values = [
    yamlencode(local.constructed_loki_helm_values),
    yamlencode(local.user_defined_loki_helm_values)
  ]
}

resource "helm_release" "promtail" {
  depends_on       = [helm_release.loki]
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  name             = "${local.instance_name}-promtail"
  cleanup_on_fail  = true
  create_namespace = true
  timeout          = lookup(local.promtail_helm_values, "timeout", 600)
  wait             = lookup(local.promtail_helm_values, "wait", false)
  recreate_pods    = lookup(local.promtail_helm_values, "recreate_pods", false)
  version          = lookup(local.promtail_helm_values, "version", "6.7.4")
  namespace        = lookup(local.promtail_helm_values, "namespace", local.loki_namespace)
  values = [
    yamlencode(local.constructed_promtail_helm_values),
    yamlencode(local.user_defined_promtail_helm_values),
    yamlencode(local.pipeline_stages)
  ]
}

resource "helm_release" "minio" {
  count            = local.is_minio_disabled ? 0 : 1
  depends_on       = [module.minio-pvc]
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "minio"
  name             = "${local.instance_name}-minio"
  cleanup_on_fail  = true
  create_namespace = true
  timeout          = lookup(local.minio_helm_values, "timeout", 600)
  wait             = lookup(local.minio_helm_values, "wait", true)
  recreate_pods    = lookup(local.minio_helm_values, "recreate_pods", false)
  version          = lookup(local.minio_helm_values, "version", "11.10.3")
  namespace        = lookup(local.minio_helm_values, "namespace", local.loki_namespace)

  values = [
    yamlencode(local.constructed_minio_helm_values),
    yamlencode(local.user_defined_minio_helm_values)
  ]

  set {
    name  = "provisioning.extraCommands[0]"
    value = "EXPIRY_DAYS=${lookup(local.spec, "retention_days", 7)}"
  }

  set {
    name  = "provisioning.extraCommands[1]"
    value = "RULE_ID=$(mc ilm ls provisioning/${local.minio_bucket} --json | jq -r 'try .config.Rules | map(select(.Filter.Prefix == \"${local.minio_bucket}/\")) | .[] .ID')"
  }

  set {
    name  = "provisioning.extraCommands[2]"
    value = "if [ -z \"$RULE_ID\" ]; then mc ilm add --prefix \"${local.minio_bucket}/\" --expiry-days $EXPIRY_DAYS provisioning/${local.minio_bucket}; else mc ilm edit --id $RULE_ID --expiry-days $EXPIRY_DAYS provisioning/${local.minio_bucket}; fi"
  }
}

module "minio-pvc" {
  count             = local.is_minio_disabled ? 0 : local.minio_replicas
  source            = "github.com/Facets-cloud/facets-utility-modules//pvc"
  name              = "data-${local.instance_name}-minio-${count.index}"
  namespace         = lookup(local.minio_helm_values, "namespace", local.loki_namespace)
  access_modes      = ["ReadWriteOnce"]
  volume_size       = lookup(local.spec, "storage_size", "5Gi")
  provisioned_for   = "${local.instance_name}-minio-${count.index}"
  instance_name     = local.instance_name
  kind              = "log_collector"
  additional_labels = lookup(local.minio_helm_values, "pvc_labels_minio", {})
  cloud_tags        = var.environment.cloud_tags
}

resource "kubernetes_config_map" "grafana_loki_datasource_cm" {
  depends_on = [helm_release.loki]
  metadata {
    name = "${local.instance_name}-loki-datasource"
    labels = merge({
      grafana_datasource = "1",
      datasource_name    = local.instance_name
      }
    )
    namespace = var.environment.namespace
  }
  data = {
    "datasource-loki-${local.instance_name}.yaml" = yamlencode(
      {
        apiVersion = 1
        datasources = [
          {
            name      = "Facets Loki"
            type      = "loki"
            url       = "http://${local.loki_endpoint}"
            access    = "proxy"
            isDefault = false
            jsonData = {
              timeout       = local.query_timeout
              derivedFields = local.derived_fields
            }
          }
        ]
      }
    )
  }
}

resource "helm_release" "loki_canary" {
  count            = lookup(local.spec, "enable_loki_canary", false) ? 1 : 0
  depends_on       = [helm_release.loki]
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-canary"
  name             = "${local.instance_name}-loki-canary"
  cleanup_on_fail  = true
  create_namespace = true
  timeout          = lookup(local.spec, "loki_canary_timeout", 600)
  wait             = lookup(local.spec, "loki_canary_wait", true)
  recreate_pods    = lookup(local.spec, "loki_canary_recreate_pods", false)
  version          = lookup(local.spec, "loki_canary_version", "0.10.0")
  namespace        = local.loki_namespace

  values = [
    yamlencode(local.loki_canary)
  ]

  set {
    name  = "lokiAddress"
    value = "${local.loki_endpoint}:80"
  }

  set {
    name  = "serviceMonitor.enabled"
    value = "true"
  }
}

data "kubernetes_service" "loki_gateway" {
  depends_on = [
    helm_release.loki
  ]
  metadata {
    name      = "${local.instance_name}-loki-distributed-gateway"
    namespace = local.loki_namespace
  }
}

resource "aws_route53_record" "loki_gateway" {
  count = lookup(local.spec, "enable_route53_record", false) && var.inputs.aws_cloud_account != null ? 1 : 0
  depends_on = [
    helm_release.loki
  ]
  zone_id = lookup(local.spec, "route53_zone_id", "")
  name    = lower("${lookup(local.spec, "route53_domain_prefix", "loki")}.${lookup(local.spec, "route53_base_domain", "")}")
  records = [local.record_type == "CNAME" ? data.kubernetes_service.loki_gateway.status.0.load_balancer.0.ingress.0.hostname : data.kubernetes_service.loki_gateway.status.0.load_balancer.0.ingress.0.ip]
  type    = local.record_type
  ttl     = "300"
}
