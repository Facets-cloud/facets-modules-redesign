locals {
  output_attributes = {
    loki_release_name       = helm_release.loki.name
    loki_namespace          = helm_release.loki.namespace
    loki_chart_version      = helm_release.loki.version
    loki_release_status     = helm_release.loki.status
    promtail_release_name   = helm_release.promtail.name
    promtail_chart_version  = helm_release.promtail.version
    promtail_release_status = helm_release.promtail.status
    loki_gateway_url        = "http://${var.instance_name}-loki-loki-distributed-gateway.${local.namespace}.svc.cluster.local"
    loki_push_url           = "http://${var.instance_name}-loki-loki-distributed-gateway.${local.namespace}.svc.cluster.local/loki/api/v1/push"
    s3_bucket_name          = local.bucket_name
    iam_role_arn            = aws_iam_role.loki.arn
  }

  output_interfaces = {}
}
