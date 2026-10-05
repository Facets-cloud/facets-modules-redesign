data "aws_region" "current" {}

resource "aws_iam_policy" "readwrite" {
  count       = local.manage_iam ? 1 : 0
  name        = "${var.environment.unique_name}-${var.instance_name}-readwrite"
  path        = "/"
  description = "${var.environment.unique_name}-${var.instance_name}-readwrite"
  tags        = var.environment.cloud_tags
  policy      = local.readwrite_policy
}

module "irsa" {
  source = "./aws_irsa"
  count  = local.manage_iam ? 1 : 0
  iam_arns = {
    s3_read_write_access = {
      arn = aws_iam_policy.readwrite[0].arn
    }
  }
  iam_role_name         = "${local.sa_name}-service-role"
  namespace             = local.loki_namespace
  sa_name               = local.sa_name
  eks_oidc_provider_arn = try(var.inputs.kubernetes_details.attributes.legacy_outputs.k8s_details.oidc_provider_arn, var.inputs.kubernetes_details.attributes.oidc_provider_arn)
}

module "log_collector" {
  source = "./log_collector"

  instance      = local.log_collector
  instance_name = var.instance_name
  environment   = var.environment
  cluster       = { awsRegion = data.aws_region.current.name }
  baseinfra     = {}
  cc_metadata   = { tenant_base_domain = "", tenant_base_domain_id = "" }
  inputs        = var.inputs
  providers = {
  }
}
