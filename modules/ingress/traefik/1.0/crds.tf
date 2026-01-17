# CRD Installation for Traefik and Gateway API
# Set enable_crds=true for first instance, false for additional instances in the same cluster

locals {
  enable_crds         = lookup(local.spec, "enable_crds", true)
  gateway_api_version = lookup(local.spec, "gateway_api_version", "v1.2.0")
  # Use experimental channel to include BackendTLSPolicy CRD that Traefik requires
  gateway_api_crds_url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${local.gateway_api_version}/experimental-install.yaml"
}

# Install Traefik CRDs using the dedicated traefik-crds helm chart
resource "helm_release" "traefik_crds" {
  count = local.enable_crds ? 1 : 0

  name             = "${local.name}-traefik-crds"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik-crds"
  namespace        = local.namespace
  create_namespace = lookup(local.spec, "create_namespace", true)

  # Wait for CRDs to be fully established
  wait = true
}

# Install Gateway API CRDs using kubectl apply
resource "null_resource" "gateway_api_crds" {
  count = local.enable_crds ? 1 : 0

  triggers = {
    version = local.gateway_api_version
  }

  provisioner "local-exec" {
    command = "kubectl apply --experimental-server-side -f ${local.gateway_api_crds_url}"
  }

  depends_on = [helm_release.traefik_crds]
}
