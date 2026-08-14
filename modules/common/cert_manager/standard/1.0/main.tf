# Define your terraform resources here

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = local.cert_mgr_namespace
  }
}

resource "helm_release" "cert_manager" {
  depends_on       = [kubernetes_namespace.namespace]
  name             = "cert-manager"
  chart            = "${path.module}/cert-manager-v1.20.3.tgz"
  namespace        = local.cert_mgr_namespace
  create_namespace = false
  cleanup_on_fail  = lookup(local.cert_manager, "cleanup_on_fail", true)
  wait             = lookup(local.cert_manager, "wait", true)
  atomic           = lookup(local.cert_manager, "atomic", false)
  timeout          = lookup(local.cert_manager, "timeout", 600)
  recreate_pods    = lookup(local.cert_manager, "recreate_pods", false)

  values = [
    yamlencode({
      # installCRDs was deprecated for crds.enabled in newer charts.
      crds = {
        enabled = true
      }

      # Garbage-collect the TLS secret when its Certificate is deleted (ownerReference).
      # Prevents orphaned cert secrets surviving teardown and breaking the next release.
      enableCertificateOwnerRef = true

      # prometheus_id carried as a common label (v1.20 chart schema rejects unknown
      # root keys; the old chart silently ignored a root prometheus_id value).
      global = {
        commonLabels = try(var.inputs.prometheus_details.attributes.helm_release_id, "") != "" ? {
          prometheus_id = var.inputs.prometheus_details.attributes.helm_release_id
        } : {}
      }

      nodeSelector = local.nodeSelector
      tolerations  = local.tolerations
      replicaCount = 2

      # Enable Gateway API support via config
      config = {
        enableGatewayAPI = local.enable_gateway_api
      }

      # The ListenerSets feature gate only makes the feature available; the
      # --enable-gateway-api-listenerset arg actually starts the listenerset shim
      # controller so cert-manager issues certs for ListenerSet TLS listeners.
      extraArgs = local.enable_gateway_api ? ["--enable-gateway-api-listenerset"] : []

      webhook = {
        nodeSelector = local.nodeSelector
        tolerations  = local.tolerations
        replicaCount = 3
      }
      cainjector = {
        nodeSelector = local.nodeSelector
        tolerations  = local.tolerations
      }
      startupapicheck = {
        nodeSelector = local.nodeSelector
        tolerations  = local.tolerations
      }
      prometheus = {
        enabled = local.prometheus_enabled
        servicemonitor = {
          enabled = local.prometheus_enabled
        }
      }
    }),
    # Gateway API + ListenerSet (gateway-shim on ListenerSet) feature gates when enabled.
    # ListenerSets requires ExperimentalGatewayAPISupport.
    local.enable_gateway_api ? yamlencode({
      featureGates = "ExperimentalGatewayAPISupport=true,ListenerSets=true"
    }) : "",
    yamlencode(local.user_supplied_helm_values),
  ]

}

module "cluster-issuer" {
  depends_on = [helm_release.cert_manager]
  for_each   = local.environments

  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = each.value.name
  namespace       = local.cert_mgr_namespace
  advanced_config = {}

  data = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = each.value.name
    }
    spec = {
      acme = {
        email  = local.acme_email
        server = each.value.url
        privateKeySecretRef = {
          name = "letsencrypt-${each.key}-account-key"
        }
        solvers = each.value.solvers
      }
    }
  }

}
