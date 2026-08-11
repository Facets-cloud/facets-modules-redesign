locals {
  _exec_args = ["-c", "command -v aws-iam-authenticator >/dev/null 2>&1 || (curl -sLo /tmp/aws-iam-authenticator https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.7.8/aws-iam-authenticator_0.7.8_linux_amd64 && chmod +x /tmp/aws-iam-authenticator && mv /tmp/aws-iam-authenticator /usr/local/bin/aws-iam-authenticator); aws-iam-authenticator token -i ${aws_eks_cluster.this.name} --role ${var.inputs.cloud_account.attributes.aws_iam_role} -s facets-k8s-${var.instance_name} -e ${var.inputs.cloud_account.attributes.external_id} --region ${var.inputs.cloud_account.attributes.aws_region}"]
  _k8s_exec = {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "bash"
    args        = local._exec_args
  }

  output_attributes = {
    cloud_provider                    = "AWS"
    cluster_arn                       = aws_eks_cluster.this.arn
    cluster_endpoint                  = aws_eks_cluster.this.endpoint
    cluster_ca_certificate            = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
    cluster_id                        = aws_eks_cluster.this.id
    cluster_name                      = aws_eks_cluster.this.name
    cluster_location                  = local.region
    cluster_version                   = aws_eks_cluster.this.version
    cluster_security_group_id         = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
    cluster_primary_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
    cluster_iam_role_arn              = local.cluster_role_arn
    oidc_issuer_url                   = aws_eks_cluster.this.identity[0].oidc[0].issuer
    oidc_provider                     = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
    oidc_provider_arn                 = aws_iam_openid_connect_provider.this.arn
    node_iam_role_arn                 = "arn:aws:iam::590183767672:role/saas-dev-k8s-cluster2024030708283054570000000a"
    node_iam_role_name                = "saas-dev-k8s-cluster2024030708283054570000000a"
    node_security_group_id            = "sg-0b4288db4bb445d11"
    kubernetes_provider_exec          = local._k8s_exec
    secrets                           = ["cluster_ca_certificate", "kubernetes_provider_exec"]
  }
  output_interfaces = {
    kubernetes = {
      host                     = aws_eks_cluster.this.endpoint
      cluster_ca_certificate   = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
      kubernetes_provider_exec = local._k8s_exec
      secrets                  = ["cluster_ca_certificate", "kubernetes_provider_exec"]
    }
  }
}
