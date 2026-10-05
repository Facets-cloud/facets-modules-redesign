locals {
  oidc_issuer_url = aws_eks_cluster.this.identity[0].oidc[0].issuer

  # exec args copied verbatim from kubernetes_cluster/eks_standard/1.0, with the cluster name
  # sourced from the raw aws_eks_cluster.this instead of module.eks.
  kubernetes_provider_exec = {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "bash"
    args        = ["-c", "command -v aws-iam-authenticator >/dev/null 2>&1 || (curl -sLo /tmp/aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.7.8/aws-iam-authenticator_0.7.8_linux_amd64 && chmod +x /tmp/aws-iam-authenticator && mv /tmp/aws-iam-authenticator /usr/local/bin/aws-iam-authenticator); aws-iam-authenticator token -i ${aws_eks_cluster.this.name} --role ${var.inputs.cloud_account.attributes.aws_iam_role} -s facets-k8s-${var.instance_name} -e ${var.inputs.cloud_account.attributes.external_id} --region ${var.inputs.cloud_account.attributes.aws_region}"]
  }

  output_attributes = {
    cluster_endpoint                  = aws_eks_cluster.this.endpoint
    cluster_ca_certificate            = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
    cluster_name                      = aws_eks_cluster.this.name
    cluster_version                   = aws_eks_cluster.this.version
    cluster_arn                       = aws_eks_cluster.this.arn
    cluster_id                        = aws_eks_cluster.this.id
    oidc_issuer_url                   = local.oidc_issuer_url
    oidc_provider                     = replace(local.oidc_issuer_url, "https://", "")
    oidc_provider_arn                 = aws_iam_openid_connect_provider.this.arn
    node_iam_role_arn                 = aws_iam_role.workers.arn
    node_iam_role_name                = aws_iam_role.workers.name
    node_security_group_id            = aws_security_group.workers.id
    cluster_iam_role_arn              = aws_iam_role.cluster.arn
    cluster_primary_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
    cluster_security_group_id         = aws_security_group.cluster.id
    cloud_provider                    = "AWS"
    cluster_location                  = var.inputs.cloud_account.attributes.aws_region
    kubernetes_provider_exec          = local.kubernetes_provider_exec
    secrets                           = ["cluster_ca_certificate", "kubernetes_provider_exec"]
  }

  output_interfaces = {
    kubernetes = {
      host                     = aws_eks_cluster.this.endpoint
      cluster_ca_certificate   = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
      kubernetes_provider_exec = local.kubernetes_provider_exec
      secrets                  = ["cluster_ca_certificate", "kubernetes_provider_exec"]
    }
  }
}
