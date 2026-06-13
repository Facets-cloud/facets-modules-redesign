locals {
  service_account_name = "facets-admin"
  namespace            = "kube-system"
}

# Create ServiceAccount
resource "kubernetes_service_account" "facets_admin" {
  metadata {
    name      = local.service_account_name
    namespace = local.namespace
  }
}

# Create ClusterRoleBinding for admin access
resource "kubernetes_cluster_role_binding" "facets_admin" {
  metadata {
    name = "${local.service_account_name}-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.facets_admin.metadata[0].name
    namespace = kubernetes_service_account.facets_admin.metadata[0].namespace
  }
}

# Create a secret for the service account token
resource "kubernetes_secret" "facets_admin_token" {
  metadata {
    name      = "${local.service_account_name}-token"
    namespace = local.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.facets_admin.metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true

  depends_on = [
    kubernetes_service_account.facets_admin
  ]
}

# Extract the token after it's generated
data "kubernetes_secret" "facets_admin_token" {
  metadata {
    name      = kubernetes_secret.facets_admin_token.metadata[0].name
    namespace = kubernetes_secret.facets_admin_token.metadata[0].namespace
  }
}

# Make callback to control plane
resource "null_resource" "add_k8s_creds_backend" {
  triggers = {
    host       = var.inputs.kubernetes_details.attributes.cluster_endpoint
    token      = data.kubernetes_secret.facets_admin_token.data["token"]
    cluster_id = var.environment.environment_id
  }

  provisioner "local-exec" {
    # Use TF_VAR_* environment variables directly in shell command
    # This replaces the deprecated var.cc_metadata pattern
    command = <<EOF
curl -X POST "https://$TF_VAR_cc_host/cc/v1/clusters/${var.environment.environment_id}/credentials" \
  -H "accept: */*" \
  -H "Content-Type: application/json" \
  -d "{\"kubernetesApiEndpoint\": \"${var.inputs.kubernetes_details.attributes.cluster_endpoint}\", \"kubernetesToken\": \"${data.kubernetes_secret.facets_admin_token.data["token"]}\"}" \
  -H "X-DEPLOYER-INTERNAL-AUTH-TOKEN: $TF_VAR_cc_auth_token"
EOF
  }

  depends_on = [
    kubernetes_cluster_role_binding.facets_admin,
    data.kubernetes_secret.facets_admin_token
  ]
}
