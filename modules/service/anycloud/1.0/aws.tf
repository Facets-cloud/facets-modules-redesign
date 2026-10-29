# ── EKS IRSA role (same-cloud) ──────────────────────────────────────────────────────────────────
# AWS-only resources. Created in the WORKLOAD account (aws provider from cloud_account = the EKS
# cluster's own account) when cloud_permissions.aws.enable_irsa is on (count-gated to 0 on GCP).
# Trust federates the cluster's OWN OIDC provider, scoped to this workload's KSA; the SA is
# annotated with the role arn (main.tf).
resource "aws_iam_role" "irsa" {
  count = local.irsa_enabled ? 1 : 0
  name  = substr("${module.sr-name.name}-irsa", 0, 64)

  lifecycle {
    precondition {
      condition     = local.eks_oidc_arn != "" && local.eks_oidc_provider != ""
      error_message = "IRSA needs the EKS OIDC provider. Wire the kubernetes_cluster input to the default output of a kubernetes_cluster/anycloud resource."
    }
  }

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.eks_oidc_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.eks_oidc_provider}:sub" = "system:serviceaccount:${local.namespace}:${local.ksa_name}"
          "${local.eks_oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# Managed policies + optional inline policy attach to the created IRSA role.
resource "aws_iam_role_policy_attachment" "irsa" {
  for_each   = local.irsa_enabled ? toset(local.iam_policy_arns) : []
  role       = aws_iam_role.irsa[0].name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "irsa_inline" {
  count = local.irsa_enabled && local.aws_inline_policy != "" ? 1 : 0
  name  = "${module.sr-name.name}-irsa-inline"
  role  = aws_iam_role.irsa[0].id
  # count-gated off when empty; "{}" keeps `policy` valid JSON for terraform validate.
  policy = local.aws_inline_policy != "" ? local.aws_inline_policy : "{}"
}
