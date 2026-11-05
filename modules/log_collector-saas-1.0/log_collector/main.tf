# using random_password resource instead of 3_utility/password since minio password has regex constrait [\w+=,.@-]+


resource "helm_release" "loki" {
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-distributed"
  name             = local.instance_name
  cleanup_on_fail  = true
  create_namespace = true
  timeout          = lookup(local.loki_helm, "timeout", 600)
  wait             = lookup(local.loki_helm, "wait", true)
  recreate_pods    = lookup(local.loki_helm, "recreate_pods", false)
  version          = lookup(local.loki_helm, "version", "0.69.0")
  namespace        = local.loki_namespace
  values = [
    yamlencode(local.constructed_loki_helm_values),
    yamlencode(local.user_defined_loki_helm_values)
  ]
  # saas-cp stays the live owner until handoff; never overwrite its values (1155 incident)
  lifecycle {
    ignore_changes = [
      values, chart, version, repository,
      create_namespace, max_history, wait, cleanup_on_fail, atomic, timeout, recreate_pods, name,
    ]
  }
}

resource "helm_release" "promtail" {
  depends_on       = [helm_release.loki]
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  name             = "${local.instance_name}-promtail"
  cleanup_on_fail  = true
  create_namespace = true
  timeout          = lookup(local.promtail_helm, "timeout", 600)
  wait             = lookup(local.promtail_helm, "wait", false)
  recreate_pods    = lookup(local.promtail_helm, "recreate_pods", false)
  version          = lookup(local.promtail_helm, "version", "6.7.4")
  namespace        = lookup(local.promtail_helm, "namespace", "facets")
  values = [
    yamlencode(local.constructed_promtail_helm_values),
    yamlencode(local.user_defined_promtail_helm_values),
    yamlencode(local.pipeline_stages)
  ]
  # saas-cp stays the live owner until handoff; never overwrite its values (1155 incident)
  lifecycle {
    ignore_changes = [
      values, chart, version, repository,
      create_namespace, max_history, wait, cleanup_on_fail, atomic, timeout, recreate_pods, name,
    ]
  }
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
            name      = "Facets Loki ${local.instance_name}"
            type      = "loki"
            url       = "http://${local.loki_endpoint}"
            access    = "proxy"
            isDefault = false,
            jsonData = {
              timeout = local.query_timeout
              derivedFields = local.derived_fields
            }
          }
        ]
      }
    )
  }
  lifecycle {
    ignore_changes = [data]
  }
}



data "kubernetes_service" "loki_gateway" {
  depends_on = [
    helm_release.loki
  ]
  metadata {
    name      = "${local.instance_name}-loki-distributed-gateway"
    namespace = "facets"
  }
}

resource "aws_route53_record" "loki_gateway" {
  count = lookup(local.loki, "enable_vm_scrape", false) ? 1 : 0
  depends_on = [
    helm_release.loki
  ]
  zone_id  = var.cc_metadata.tenant_base_domain_id
  name     = lower("${local.loki.domain_prefix}.${var.cc_metadata.tenant_base_domain}")
  records  = [local.record_type == "CNAME" ? data.kubernetes_service.loki_gateway.status.0.load_balancer.0.ingress.0.hostname : data.kubernetes_service.loki_gateway.status.0.load_balancer.0.ingress.0.ip]
  type     = local.record_type
  ttl      = "300"
  provider = aws3tooling
}