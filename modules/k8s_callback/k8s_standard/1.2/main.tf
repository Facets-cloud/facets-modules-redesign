locals {
  spec = lookup(var.instance, "spec", {})

  # Names are override-only so an EXISTING admin service account can be adopted at zero change.
  # Defaults reproduce the previous hardcoded behaviour exactly, so existing consumers are unaffected.
  service_account_name      = lookup(local.spec, "service_account_name", "facets-admin")
  namespace                 = lookup(local.spec, "namespace", "kube-system")
  cluster_role_binding_name = lookup(local.spec, "cluster_role_binding_name", "${local.service_account_name}-binding")
  token_secret_name         = lookup(local.spec, "token_secret_name", "${local.service_account_name}-token")

  # The callback POSTs a cluster-admin token to the control plane and registers it as this
  # cluster's credential. That is a WRITE to control-plane state, so it must be switchable off
  # when adopting a cluster whose credentials are already registered (or which runs on
  # in-cluster identity). Defaults to true = previous behaviour.
  enable_callback = lookup(local.spec, "enable_callback", true)
}

# Create ServiceAccount
resource "kubernetes_service_account" "facets_admin" {
  metadata {
    name      = local.service_account_name
    namespace = local.namespace
  }

  # imagePullSecrets are patched onto this service account out-of-band by the ECR token
  # refresher, so terraform must not fight it. The legacy facets-iac module ignores this
  # field for the same reason.
  lifecycle {
    ignore_changes = [image_pull_secret]
  }
}

# Create ClusterRoleBinding for admin access
resource "kubernetes_cluster_role_binding" "facets_admin" {
  metadata {
    name = local.cluster_role_binding_name
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
    name      = local.token_secret_name
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

# Extract the token after it's generated. Only read when the callback needs it — otherwise a
# cluster-admin token would be pulled into terraform state for no reason.
data "kubernetes_secret" "facets_admin_token" {
  count = local.enable_callback ? 1 : 0

  metadata {
    name      = kubernetes_secret.facets_admin_token.metadata[0].name
    namespace = kubernetes_secret.facets_admin_token.metadata[0].namespace
  }
}

# Make callback to control plane
resource "null_resource" "add_k8s_creds_backend" {
  count = local.enable_callback ? 1 : 0

  triggers = {
    host       = var.inputs.kubernetes_details.cluster_endpoint
    token      = data.kubernetes_secret.facets_admin_token[0].data["token"]
    cluster_id = var.environment.environment_id
  }

  provisioner "local-exec" {
    # Use TF_VAR_* environment variables directly in shell command
    # This replaces the deprecated var.cc_metadata pattern
    command = <<EOF
curl -X POST "https://$TF_VAR_cc_host/cc/v1/clusters/${var.environment.environment_id}/credentials" \
  -H "accept: */*" \
  -H "Content-Type: application/json" \
  -d "{\"kubernetesApiEndpoint\": \"${var.inputs.kubernetes_details.cluster_endpoint}\", \"kubernetesToken\": \"${data.kubernetes_secret.facets_admin_token[0].data["token"]}\"}" \
  -H "X-DEPLOYER-INTERNAL-AUTH-TOKEN: $TF_VAR_cc_auth_token"
EOF
  }

  depends_on = [
    kubernetes_cluster_role_binding.facets_admin,
    data.kubernetes_secret.facets_admin_token
  ]
}
